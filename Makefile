.PHONY: all default build-images fetch clean clean-bucket test serve build release export shell

PROJECT_NAME ?= docsdockercom
DOCKER_COMPOSE := docker-compose -p $(PROJECT_NAME)
DOCKER_IP = $(shell python -c "import urlparse ; print urlparse.urlparse('$(DOCKER_HOST)').hostname or ''")
HUGO_BASE_URL = $(shell test -z "$(DOCKER_IP)" && echo localhost || echo "$(DOCKER_IP)")
HUGO_BIND_IP = 0.0.0.0
DATA_CONTAINER_CMD = $(DOCKER_COMPOSE) ps -q data | head -n 1
RELEASE_LATEST ?=

ifndef RELEASE_LATEST
	DOCS_VERSION = $(shell cat VERSION | head -n1 | awk '{print $$1}')
else
	DOCS_VERSION =
endif

default: build-images build

build-images:
	$(DOCKER_COMPOSE) build ; \
	CONTAINER_ID=$$( $(DOCKER_COMPOSE) run -d fetch true) ; \
	until IMAGE_NAME=$$( docker inspect -f "{{ .Config.Image }}" "$$CONTAINER_ID" ) && [ -n "$$IMAGE_NAME" ] ; do echo "sleep $$CONTAINER_ID" ; sleep 1; done ; \
	docker tag -f "$$IMAGE_NAME" "$(PROJECT_NAME):latest" ; \
	docker rm -f "$$CONTAINER_ID" >/dev/null

fetch:
	$(DOCKER_COMPOSE) up fetch

clean:
	$(DOCKER_COMPOSE) rm -fv ; \
	docker rmi $$( docker images | grep -E '^$(PROJECT_NAME)_' | awk '{print $$1}' ) 2>/dev/null ||:

clean-bucket:
	RM_OLDER_THAN="$(RM_OLDER_THAN)" $(DOCKER_COMPOSE) run --rm cleanup

serve: fetch
	HUGO_BIND_IP=$(HUGO_BIND_IP) HUGO_BASE_URL=$(HUGO_BASE_URL) $(DOCKER_COMPOSE) up serve

build: fetch
	DOCS_VERSION=$(DOCS_VERSION) $(DOCKER_COMPOSE) up build

release: build
	CLEAN=$(DOCS_VERSION) $(DOCKER_COMPOSE) up upload

export: build
	docker cp $$($(DATA_CONTAINER_CMD)):/public - | gzip > docs-docker-com.tar.gz

shell: build
	$(DOCKER_COMPOSE) run --rm build /bin/bash

markdownlint:
	docker exec -it docsdockercom_serve_1 /usr/local/bin/markdownlint /docs/content/

htmllint:
	docker exec -it docsdockercom_serve_1 /usr/local/bin/linkcheck http://127.0.0.1:8000

all: clean build build-images serve

# Sven doesn't have docker-compose installed on some boxes, so use a compose container
compose:
	docker run --rm -it \
		-e GITHUB_USERNAME -e GITHUB_TOKEN \
		-v $(CURDIR):$(CURDIR) \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /usr/bin/docker-static:/usr/bin/docker \
		-w $(CURDIR) \
		--entrypoint bash \
			svendowideit/compose
