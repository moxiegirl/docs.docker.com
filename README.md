# README 

This project builds and releases the documentation for all of Docker &ndash; both open source and commercial. 

## Prerequisites
  
 The build system allows you to build any public or private repo. To build a
 private repo, the build system requires your GitHub username and an access
 token. If you don't have an access token, you can create one by following
 [Creating an access token for command-line
 use](https://help.github.com/articles/creating-an-access-token-for-command-line-use/).
   
 Your system should have a recent installation of both Docker Engine and Docker
 Compose.  See the [installation procedures](http://docs.docker.com/) for
 details on how to install these.
 
 Finally, it is convenient to have the [AWS command line
 tools](http://aws.amazon.com/cli/) installed. This is not required though.

## Quickstart publish docs

1. Clone the `docs.docker.com` repository.
    
2. Change to your local `docs.docker.com` repository.

3. If you are releasing a new version, edit the `VERSION` file and set the version.
  
    The build system uses the version to identify the subfolder on S3 representing the released material, for example, the `AWS_S3_BUCKET/v1.7` folder.
    
4. Edit the `all-projects.yml` file and configure one or more `projects` to build.

    | Value       | Description                                                                                                             |
    |-------------|-------------------------------------------------------------------------------------------------------------------------|
    | `org`       | GitHub username or team name owning the repo.                                                                                           |
    | `ref`       | Branch or tag name.                                                                                                     |
    | `path`      | Location in repository to pull from.  To pull an entire repository from the root directory, specify `!!null` as a path. |
    | `repo_name` | The name of the repository to pull. If you don't specify this value, then you must specify `name`.                      |
    | `name`      | Name of the destination directory in the container. The build system copies into a folder by this name.                 |
    | `target`    | The subdirectory in the container the build creates so the build creates `target`/`name` in the container.              |
    | `ignores`   | Specifies files / folders to ignore.                                                                                    |

  Any values that are common across all projects, add to the `defaults` block.
  For example, these `defaults` indicate all the repos you intend to build
  belong to `docker`.
  
      defaults:
          org: docker
          ref: docs
          path: docs
          repo_name: "{name}"
          name: "{repo_name}"
          target: "content/{name}"
          ignores: ['.*/Dockerfile']

      projects:
          - name: docs-base
            ref: hugo
            org: docker
            path: !!null
            target: .

          - name: docker
            ref: docs
            path: docs/

  You can override the defaults on any entry. This specifies to build the
  `hugo-test-fixes` branch belonging to the `https://github.com/moxiegirl/docker`
  fork:
  
          - name: docker
            orgh: moxiegirl
            ref: hugo-test-fixes
            path: docs/
            
5. Set your GitHub credentials: these are required. 

        $ export GITHUB_USERNAME=moxiegirl
        $ export GITHUB_TOKEN=1077107f8a57cec307f7355a1ac22ecc4d5223dc
        
  The above are example values of course. 
        
6. If you are publishing externally, specify the location of the bucket to build to and the access creds. 
  
        $ export AWS_ACCESS_KEY_ID=AKIAIKGKXQ3QTG3QY1SY
        $ export AWS_SECRET_ACCESS_KEY=qFlobtw3yYXdtEppahJAZKoNcDUXleTKB23kFR6c
        $ export AWS_S3_BUCKET=docs-manthony
        $ export S3HOSTNAME=mary.docs.test.s3-website-us-west-2.amazonaws.com

    The above are example values of course. You'll need to use valid values to publish.

    Alternatively, you can set the values in a `aws.env` file beside the Makefile in `docs.docker.com`.
    The Makefile will automatically include any values that are set in this file.
    The environment variables you can set include:

        AWS_USER=sven
        AWS_ACCESS_KEY_ID=KAZ7ZFJNLA
        AWS_SECRET_ACCESS_KEY=geMzVXko+j2jfye9Sa4J
        AWS_S3_BUCKET=sven
        GITHUB_TOKEN=3a5dec0bda7634176339
        GITHUB_USERNAME=SvenDowideit
        S3HOSTNAME=sven.s3-website-us-east-1.amazonaws.com
        CHECKURL=http://sven.s3-website-us-east-1.amazonaws.com
        RELEASE_LATEST=1

6. Clean any old images from previous passes.

        $ make clean

7. Build the necessary images used by the system.

        $ make build-images

8. Run the server locally to test and review your changes.

        $ make serve

9. Release to the subfolder (created if it doesn't exist).

        $ make release     

9a. Re-set the s3 redirects

    The `make release` command also sets up the redirects, but if you need to
    update them separately, you can run:

        $ make redirects

10. Optionally, check for new or updated bucket.

        $ aws s3 ls s3://$AWS_S3_BUCKET/
                                   PRE article-img/
                                   PRE articles/
                                   PRE compose/
                                   PRE css/
                                   PRE dist/
                                   PRE docker-hub-enterprise/
                                   PRE docker-hub/
        ...snip...
                                   PRE userguide/
                                   PRE v1.7/
                                   PRE windows/

11. Upload the content to the bucket root.

        $ RELEASE_LATEST=1 make release 


