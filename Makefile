.PHONY: all build clean clean-bucket test serve release export shell

AWSTOKENSFILE ?= aws.env
-include ${AWSTOKENSFILE}
export GITHUB_USERNAME GITHUB_TOKEN AWS_USER AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

S3HOSTNAME?=${AWS_S3_BUCKET}.s3-website-us-east-1.amazonaws.com
export S3HOSTNAME

CHECKURL=http://${S3HOSTNAME}/
export CHECKURL

export IMAGE_TAG ?= $(shell git rev-parse --abbrev-ref HEAD)
DOCKER_IMAGE := docsdockercom:$(IMAGE_TAG)
CONTAINER_NAME := docsdockercom-$(IMAGE_TAG)

# set when uploading to the root of the bucket
export RELEASE_LATEST
export DOCS_VERSION = $(shell cat VERSION | head -n1 | awk '{print $$1}')

# Start of commands
docs: all

all: clean serve

# The result of this step should become a hub image that the Docker projects can use for local testing
build:
	docker build \
		-t $(DOCKER_IMAGE) \
		.

serve: build
	docker run --rm -it \
		-p 8000:8000 \
		-w "/docs" \
		-e GITHUB_USERNAME \
		-e GITHUB_TOKEN \
		$(DOCKER_IMAGE) \
		serve

release: clean upload

clean:
	docker rmi -f $(DOCKER_IMAGE) 2>/dev/null ||:

upload: build
	docker run --rm -it \
		-e CLEAN=$(CLEAN) \
		-e RELEASE_LATEST=$(RELEASE_LATEST) \
		-e DOCS_VERSION=$(DOCS_VERSION) \
		-e AWS_USER=$(AWS_USER) \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_S3_BUCKET=$(AWS_S3_BUCKET) \
		-e GITHUB_USERNAME \
		-e GITHUB_TOKEN \
		-e S3HOSTNAME=$(S3HOSTNAME) \
		-w "/docs" \
		$(DOCKER_IMAGE) \
			build_and_upload

# BEWARE that the $S3HOSTNAME will be embedded in some of the output html
export: build
	docker run --name $(CONTAINER_NAME) -it \
		-e S3HOSTNAME=$(S3HOSTNAME) \
		-e GITHUB_USERNAME \
		-e GITHUB_TOKEN \
		-w "/docs" \
		$(DOCKER_IMAGE) \
			build
	docker cp $(CONTAINER_NAME):/public - | gzip > docs-docker-com.tar.gz
	docker rm -vf $(CONTAINER_NAME)

shell: build
	docker run --rm -it \
		-p 8000:8000 \
		-w "/docs" \
		-e GITHUB_USERNAME \
		-e GITHUB_TOKEN \
		-e S3HOSTNAME=$(S3HOSTNAME) \
		-e DOCS_VERSION=$(DOCS_VERSION) \
		-e AWS_USER=$(AWS_USER) \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_S3_BUCKET=$(AWS_S3_BUCKET) \
		$(DOCKER_IMAGE) \
			bash


htmllint-s3: build
	docker run -d -it \
		--name $(CONTAINER_NAME) \
		-w "/docs" \
		-e CHECKURL=$(CHECKURL) \
		$(DOCKER_IMAGE) \
		htmllint


test: buld
	docker run --rm -it \
		-w "/docs" \
		-e GITHUB_USERNAME \
		-e GITHUB_TOKEN \
		$(DOCKER_IMAGE) \
		test

redirects:
	docker build -t docsdockercom_redirects -f Dockerfile.redirects .
	docker run \
		--rm -it \
		-e S3HOSTNAME=$(S3HOSTNAME) \
		-e AWS_USER=$(AWS_USER) \
 		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_S3_BUCKET=$(AWS_S3_BUCKET) \
		docsdockercom_redirects

clean-bucket: build
	docker run --rm -it \
		-e S3HOSTNAME=$(S3HOSTNAME) \
		-e AWS_USER=$(AWS_USER) \
 		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_S3_BUCKET=$(AWS_S3_BUCKET) \
		-e RM_OLDER_THAN=$(RM_OLDER_THAN) \
		-w "/docs" \
		$(DOCKER_IMAGE) \
		cleanup

totally-clean-bucket:
	docker run --rm -it \
		-e S3HOSTNAME=$(S3HOSTNAME) \
		-e AWS_USER=$(AWS_USER) \
 		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_S3_BUCKET=$(AWS_S3_BUCKET) \
		--entrypoint aws docs/base s3 rm --recursive s3://$(AWS_S3_BUCKET)

