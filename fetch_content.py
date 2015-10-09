import sys
import re
import io
import os.path
import tarfile
import yaml
import json

import sarge
import requests


def mkdirp(pth):
    try:
        os.makedirs(os.path.normpath(pth))
    except OSError:
        pass


def needs_format(s):
    if isinstance(s, basestring):
        return re.search(r'(?<!\\)\{.+(?<!\\)\}', s) is not None
    elif isinstance(s, list):
        return any(needs_format(x) for x in s)
    elif s is None:
        return False

    raise Exception("unknown value type:", repr(s))


def load_projects(fname):
    content = yaml.load(open(fname))
    defaults = content.get('defaults', {})

    projects = []
    for desc in content.get('projects', []):
        proj = dict()
        proj.update(defaults)
        proj.update(desc)

        while any(needs_format(x) for x in proj.values()):
            for k, v in proj.items():
                if isinstance(v, basestring):
                    proj[k] = v.format(**proj)
                elif isinstance(v, list):
                    proj[k] = [x.format(**proj) for x in v]

        projects.append(proj)

    return projects


def gather_local_git_info():
    remote_names = sarge.capture_stdout('git remote show').stdout.text.splitlines()
    remote_urls = [
        sarge.capture_stdout('git ls-remote --get-url {}'.format(name)).stdout.text.strip()
        for name in remote_names
    ]

    return dict(
        repos=remote_urls,
        ref=sarge.capture_stdout('git rev-parse --symbolic-full-name HEAD').stdout.text.strip(),
        sha=sarge.capture_stdout('git rev-parse HEAD').stdout.text.strip()
    )


def gather_git_info(org, repo_name, ref):
    info = dict(
        org=org,
        repo_name=repo_name,
        ref=ref
    )

    r = requests.get(
        'https://api.github.com/repos/{org}/{repo_name}/commits/{ref}'.format(**info),
        auth=(os.environ['GITHUB_USERNAME'], os.environ['GITHUB_TOKEN']),
    )
    print 'WARNING: request for commit info to {0}/{1} returned {2}'.format(org, repo_name, r.status_code)
    commit_info = r.json()

    info['sha'] = commit_info['sha']
    info['archive_url'] = 'https://github.com/{org}/{repo_name}/archive/{sha}.tar.gz'.format(**info)
    info['repos'] = ['git@github.com:{org}/{repo_name}.git'.format(**info)]
    info.pop('org')
    info.pop('repo_name')

    return info


def fetch_project(destination, org, repo_name, name, ref, path, ignores=None, target=None):
    git_info = gather_git_info(org, repo_name, ref)
    archive_url = git_info.pop('archive_url')

    resp = requests.get(
        archive_url,
        auth=(os.environ['GITHUB_USERNAME'], os.environ['GITHUB_TOKEN']),
        stream=True
    )

    tarfile_stream = io.BytesIO(resp.raw.read())

    tgz = tarfile.open(mode='r:gz', fileobj=tarfile_stream)

    if ignores is None:
        ignores = []

    if path and not path.endswith('/'):
        path += '/'

    for tar_info in tgz:
        if not tar_info.isfile():
            continue

        fname = tar_info.name

        if any(re.match(ignore, fname) for ignore in ignores):
            continue

        # Strip path components
        # always strip the first one
        path_parts = fname.split('/', 1)

        if len(path_parts) == 1:
            continue

        stripped_path = path_parts[1]

        # strip parts from project spec
        if path and not stripped_path.startswith(path):
            continue

        if path:
            stripped_path = stripped_path[len(path):]

        target_path = os.path.normpath(os.path.join(destination, target, stripped_path))
        mkdirp(os.path.dirname(target_path))

        print 'extracting', tar_info.name, '->', target_path
        with open(target_path, 'wb') as f:
            f.write(tgz.extractfile(tar_info).read())

    return git_info


def main(destination, projects_file=None):
    destination = os.path.normpath(destination)

    if projects_file is not None:
        projects = load_projects(projects_file)
    else:
        # projects = [LocalProject('.', 'docs')]
        raise NotImplementedError

    build_info = {}
    for project in projects:
        proj_git_info = fetch_project(destination, **project)
        build_info['{org}/{name}'.format(**project)] = proj_git_info

    build_info['docs.docker.com'] = gather_local_git_info()

    with open(os.path.join(destination, 'build.json'), 'w') as f:
        f.write(json.dumps(
            build_info,
            sort_keys=True,
            indent=4,
            separators=(',', ': ')
        ))


if __name__ == '__main__':
    main(*sys.argv[1:])
