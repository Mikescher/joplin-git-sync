
DOCKER_REPO=registry.blackforestbytes.com
DOCKER_NAME=mikescher/joplin-git-sync

build: build-only
	docker login      $(DOCKER_REPO)
	docker image push $(DOCKER_REPO)/$(DOCKER_NAME):latest

build-only:
	docker build -t $(DOCKER_REPO)/$(DOCKER_NAME):latest .

run: build-only
	docker run --rm -it  $(DOCKER_REPO)/$(DOCKER_NAME):latest
