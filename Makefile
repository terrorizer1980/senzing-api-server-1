# PROGRAM_NAME is the name of the GIT repository.
# It should match <artifactId> in pom.xml
PROGRAM_NAME := $(shell basename `git rev-parse --show-toplevel`)

# User variables.

SENZING_G2_JAR_PATHNAME ?= /opt/senzing/g2/lib/g2.jar
SENZING_G2_JAR_VERSION ?= 1.5.0-SNAPSHOT

# Information from git.

GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
GIT_REPOSITORY_NAME := $(shell basename `git rev-parse --show-toplevel`)
GIT_SHA := $(shell git log --pretty=format:'%H' -n 1)
GIT_TAG ?= $(shell git describe --always --tags | awk -F "-" '{print $$1}')
GIT_TAG_END ?= HEAD
GIT_VERSION := $(shell git describe --always --tags --long --dirty | sed -e 's/\-0//' -e 's/\-g.......//')
GIT_VERSION_LONG := $(shell git describe --always --tags --long --dirty)

# Docker.

DOCKER_IMAGE_PACKAGE := $(GIT_REPOSITORY_NAME)-package:$(GIT_VERSION)
DOCKER_IMAGE_TAG ?= $(GIT_REPOSITORY_NAME):$(GIT_VERSION)
DOCKER_IMAGE_NAME := senzing/rest-api-server-java

# -----------------------------------------------------------------------------
# The first "make" target runs as default.
# -----------------------------------------------------------------------------

.PHONY: default
default: help

# -----------------------------------------------------------------------------
# Local development
# -----------------------------------------------------------------------------

.PHONY: package
package:

	mvn install:install-file \
		-Dfile=$(SENZING_G2_JAR_PATHNAME) \
		-DgroupId=com.senzing \
		-DartifactId=g2 \
		-Dversion=$(SENZING_G2_JAR_VERSION) \
		-Dpackaging=jar
        
	mvn package \
		-Dproject.version=$(GIT_VERSION) \
		-Dgit.branch=$(GIT_BRANCH) \
		-Dgit.repository.name=$(GIT_REPOSITORY_NAME) \
		-Dgit.sha=$(GIT_SHA) \
		-Dgit.version.long=$(GIT_VERSION_LONG)

# -----------------------------------------------------------------------------
# Docker-based builds
# -----------------------------------------------------------------------------

.PHONY: docker-package
docker-package: docker-rmi-for-package
	# Make docker image.

	mkdir -p target
	cp $(SENZING_G2_JAR_PATHNAME) target/
	docker build \
		--build-arg BUILD_VERSION=$(GIT_VERSION) \
		--build-arg GIT_REPOSITORY_NAME=$(GIT_REPOSITORY_NAME) \
		--build-arg SENZING_G2_JAR_PATHNAME=$(SENZING_G2_JAR_PATHNAME) \
		--tag $(DOCKER_IMAGE_PACKAGE) \
		--file Dockerfile-package \
		.

	# Run docker image which creates a docker container.
	# Then, copy the maven output from the container to the local workstation.
	# Finally, remove the docker container.

	PID=$$(docker create $(DOCKER_IMAGE_PACKAGE) /bin/bash); \
	docker cp $$PID:/$(GIT_REPOSITORY_NAME)/target .; \
	docker rm -v $$PID

# -----------------------------------------------------------------------------
# Docker-based builds
# -----------------------------------------------------------------------------

.PHONY: docker-build
docker-build: docker-rmi-for-build
	docker build \
		--build-arg SENZING_G2_JAR_PATHNAME=target/sz-api-server-1.5.0.jar \
		--tag $(DOCKER_IMAGE_NAME) \
		--tag $(DOCKER_IMAGE_NAME):$(GIT_VERSION) \
		--file Dockerfile-build \
		.

.PHONY: docker-build-base
docker-build-base: docker-rmi-for-build-base
	docker build \
		--build-arg SENZING_G2_JAR_PATHNAME=target/sz-api-server-1.5.0.jar \
		--tag $(DOCKER_IMAGE_TAG) \
		--file Dockerfile-build \
		.

# -----------------------------------------------------------------------------
# Test ground
# -----------------------------------------------------------------------------

.PHONY: docker-all
docker-all:
	mkdir -p target
	cp $(SENZING_G2_JAR_PATHNAME) target/
	docker build \
		--build-arg BUILD_VERSION=$(GIT_VERSION) \
		--build-arg GIT_REPOSITORY_NAME=$(GIT_REPOSITORY_NAME) \
		--build-arg SENZING_G2_JAR_PATHNAME=$(SENZING_G2_JAR_PATHNAME) \
		--tag $(DOCKER_IMAGE_PACKAGE) \
		.
		
# -----------------------------------------------------------------------------
# Clean up targets
# -----------------------------------------------------------------------------

.PHONY: docker-rmi-for-build
docker-rmi-for-build:
	-docker rmi --force \
		$(DOCKER_IMAGE_NAME):$(GIT_VERSION) \
		$(DOCKER_IMAGE_NAME)

.PHONY: docker-rmi-for-build-base
docker-rmi-for-build-base:
	-docker rmi --force $(DOCKER_IMAGE_TAG)

.PHONY: docker-rmi-for-package
docker-rmi-for-packagae:
	-docker rmi --force $(DOCKER_IMAGE_PACKAGE)

.PHONY: clean
clean: docker-rmi-for-build docker-rmi-for-build-base docker-rmi-for-package

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

.PHONY: help
help:
	@echo "List of make targets:"
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs
