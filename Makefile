.PHONY: all default build-images fetch clean clean-bucket test serve build release export shell

-include aws.env

show:
	echo "S3HOSTNAME == $(S3HOSTNAME)"

PROJECT_NAME ?= docsdockercom
DOCKER_COMPOSE := docker-compose -p $(PROJECT_NAME)
export IMAGE_TAG ?= $(shell git rev-parse --abbrev-ref HEAD)
DOCKER_IMAGE := docsdockercom:$(IMAGE_TAG)
DOCKER_IP = $(shell python -c "import urlparse ; print urlparse.urlparse('$(DOCKER_HOST)').hostname or ''")
export HUGO_BASE_URL = $(shell test -z "$(DOCKER_IP)" && echo localhost || echo "$(DOCKER_IP)")
DATA_CONTAINER_CMD = $(DOCKER_COMPOSE) ps -q data | head -n 1
RELEASE_LATEST ?=

ifndef RELEASE_LATEST
	export DOCS_VERSION = $(shell cat VERSION | head -n1 | awk '{print $$1}')
else
	export DOCS_VERSION =
endif

default: build-images build

build-images:
	docker build -t $(DOCKER_IMAGE) .

fetch:
ifndef GITHUB_USERNAME
	$(error GITHUB_USERNAME is undefined)
endif
ifndef GITHUB_TOKEN
	$(error GITHUB_TOKEN is undefined)
endif
	$(DOCKER_COMPOSE) run --rm \
		  -e S3HOSTNAME=$(S3HOSTNAME) \
		fetch

clean:
	$(DOCKER_COMPOSE) rm -fv ; \
	docker rmi $$( docker images | grep -E '^$(PROJECT_NAME)_' | awk '{print $$1}' ) 2>/dev/null ||:
	docker rmi -f $(DOCKER_IMAGE) 2>/dev/null ||:

clean-bucket:
	RM_OLDER_THAN="$(RM_OLDER_THAN)" $(DOCKER_COMPOSE) run --rm cleanup

totally-clean-bucket:
	docker run --rm \
		-e AWS_USER -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_S3_BUCKET \
		--entrypoint aws docs/base s3 rm --recursive s3://$(AWS_S3_BUCKET)

serve: fetch
	$(DOCKER_COMPOSE) up serve

build: fetch
	$(DOCKER_COMPOSE) run --rm \
		  -e S3HOSTNAME=$(S3HOSTNAME) \
		build

release: test-aws-env clean build-images build upload

upload:
	CLEAN=$(DOCS_VERSION) $(DOCKER_COMPOSE) run --rm \
		  -e AWS_USER=$(AWS_USER) \
		  -e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
		  -e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
		  -e AWS_S3_BUCKET=$(AWS_S3_BUCKET) \
		  -e S3HOSTNAME=$(S3HOSTNAME) \
		  -e CLEAN=$(CLEAN) \
		  upload

export: build
	docker cp $$($(DATA_CONTAINER_CMD)):/public - | gzip > docs-docker-com.tar.gz

shell: build
	$(DOCKER_COMPOSE) run --rm \
		  -e S3HOSTNAME=$(S3HOSTNAME) \
		build /bin/bash

test:
	$(DOCKER_COMPOSE) up -d serve
	sleep 2
	$(DOCKER_COMPOSE) run --rm test bash
	$(DOCKER_COMPOSE) stop
	$(DOCKER_COMPOSE) rm -f serve

test-aws-env:
ifndef AWS_USER 
	$(error AWS_USER is undefined)
endif
ifndef AWS_ACCESS_KEY_ID
	$(error AWS_ACCESS_KEY_ID is undefined)
endif
ifndef AWS_SECRET_ACCESS_KEY
	$(error AWS_SECRET_ACCESS_KEY is undefined)
endif
ifndef AWS_S3_BUCKET
	$(error AWS_S3_BUCKET is undefined)
endif
ifndef S3HOSTNAME
	$(error S3HOSTNAME is undefined)
endif

redirects: test-aws-env
	docker build -t docsdockercom_redirects -f Dockerfile.redirects .
	docker run \
		--rm \
		-e AWS_USER -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_S3_BUCKET -e S3HOSTNAME \
		docsdockercom_redirects

markdownlint:
	docker exec -it docsdockercom_serve_1 /usr/local/bin/markdownlint /docs/content/

htmllint:
	docker exec -it docsdockercom_serve_1 /usr/local/bin/linkcheck http://127.0.0.1:8000

htmllint-s3:
ifndef CHECKURL
	$(error CHECKURL is undefined)
endif
	docker run $(DOCKER_IMAGE) /usr/local/bin/linkcheck $(CHECKURL)

all: clean build-images build serve

