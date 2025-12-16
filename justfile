# justfile for arch-multipurpose container repo

# default recipe: list available recipes
default:
    @just --list

# build the base debian container
build-debian:
    podman build -f debian/Dockerfile -t debian-dev .

# build the full debian container (includes k8s tools + LSPs)
build-debian-full: build-debian
    podman build -f debian-full/Dockerfile --build-arg BASE_IMAGE=debian-dev -t debian-full .

# build all containers
build-all: build-debian build-debian-full

# test the base debian container
test-debian: build-debian
    debian/test-container.sh debian-dev

# test the full debian container
test-debian-full: build-debian-full
    debian/test-container.sh debian-full

# test all containers
test-all: test-debian test-debian-full

# run the base debian container interactively
run-debian:
    podman run -it --rm -e SHELL=/bin/bash -e TERM={{ env_var_or_default("TERM", "xterm-256color") }} debian-dev

# run the full debian container interactively
run-debian-full:
    podman run -it --rm -e SHELL=/bin/bash -e TERM={{ env_var_or_default("TERM", "xterm-256color") }} debian-full

# run with ssh enabled
run-debian-ssh:
    podman run -it --rm -e SHELL=/bin/bash -e TERM={{ env_var_or_default("TERM", "xterm-256color") }} -e ENABLE_SSH=1 -p 2222:22 debian-dev

# list available tools in install-tool.py
list-tools:
    ./install-tool.py list

# clean up built images
clean:
    -podman rmi debian-dev debian-full 2>/dev/null

# show container sizes
sizes:
    @podman images --format 'table {{ "{{" }}.Repository{{ "}}" }}\t{{ "{{" }}.Tag{{ "}}" }}\t{{ "{{" }}.Size{{ "}}" }}' | grep -E "(debian-dev|debian-full|REPOSITORY)"
