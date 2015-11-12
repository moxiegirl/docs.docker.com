## Define projects

Determine what projects are going to be checked out and managed. Currently compose expects this in `all-projects.yml`.

### projects.yml

a `projects.yml` has two root sections: `defaults` and `projects`. `defaults` is optional, but recommended for more than two projects.

#### defaults

Any key not found in a project will use the value found in `defaults`.

#### projects

Projects is a list of project dictionaries. Each project dictionary can have the following keys:

* `org`: this is the organization (or user) on github to look for the repository.
* `repo_name`: this is the repository name. Combined with the `org` will determine the path on github to the repository.
* `name`: used in the build information added to the footer template used by hugo.
* `path`: the path within the repository that will be checked out. Use the special YAML value `!!null` to use the entire repository.
* `target`: the target location on disk to check the files out into (relative to the path provided to fetch_content.py)
* `ignores`: A list of ignore patterns that will be checked to determine if a file should not be fetched.

#### A note about substitution

The values for all keys will be run through Python's string formatting, applying the dictionary itself as the source for other values. E.g.: a value of `content/{name}` for the `target` and `foo` for the `name` will result in `target` resolving to the value `content/foo`.

---

## Development
Run `make serve` to fetch all content and run the hugo server on your `DOCKER_HOST` on port 8000. If `DOCKER_HOST` is not set, `localhost` is used.

### Deployment
This will upload the content to a directory named after the contents of the VERSION file. If an existing directory with the same name is found, it is deleted and replaced.

1. Set the following environment variables:
  * `AWS_ACCESS_KEY_ID` - your AWS access key
  * `AWS_SECRET_ACCESS_KEY` - your AWS secret
  * `AWS_S3_BUCKET` - the S3 destination. May include additional path information; i.e. `docs-beta.docker.io` and `docs-beta.docker.io/my-test` are both valid.
1. Run `make release`.

### Latest
This is to change the content at the 'root' of the S3 bucket; i.e. it does not use the `VERSION` as a directory name.

1. In addition to the AWS variables above, set `RELEASE_LATEST` to any non-empty value (e.g. `1`, `true` are appropriate).
1. Run `make release`.

This is an additive operation that will upload the built content to S3 in the root directory of the S3 bucket location. **No content will be deleted.**

### Cleanup for Latest

1. In addition to the AWS variables, set `RM_OLDER_THAN` to be a date string in the same format as output `aws s3 ls` (e.g.: `2015-01-23 14:01:19`). Make sure to obey shell quoting rules.
2. Run `make clean-bucket`

This will iterate over all files in the bucket location and perform the following steps on each:
1. If the path starts with something that looks like a version number (e.g. "vX.Y" with at least one digit for X and Y), the file is left as-is.
1. If the file was changed at or before the `RM_OLDER_THAN` date, the file is left as-is.
1. If the file is not part of a versioned directory and is last changed before the `RM_OLDER_THAN` date, the file is turned into a redirect to `index.html` in the root of the S3 bucket location.
**Note: The file still exists on S3, it is just no longer accessible via the static hosting provided by S3**.
