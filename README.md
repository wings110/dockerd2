# Magisk Docker

This repository contains a Magisk and KernelSU module for running Docker on rooted Android devices.

## Prerequisites
- Magisk or KernelSU installed
- Docker Patched kernel [See More](https://gist.github.com/FreddieOliveira/efe850df7ff3951cb62d74bd770dce27)

## Quick Start & Installation

1. Download the latest zip file from the [Releases](https://github.com/mgksu/dockerd/releases/latest) page.
2. Install the downloaded zip file using Magisk & reboot your phone.


After installation, the Docker daemon (`dockerd`) will run automatically on boot.

## Limitation

- This module only support `arm64` architecture.

## Available command

- `docker`: This command is executes docker operation.
- `dockerd.service`: This command for managing dockerd service, you can start,stop,restart daemon and view live logs the dockerd operation.

```sh
export PATH=/data/adb/docker/bin:$PATH
export DOCKER_HOST="unix:///data/adb/docker/var/run/docker.sock"
export LD_LIBRARY_PATH="/data/adb/docker/lib:$LD_LIBRARY_PATH"
```
You can add above lines to your shell profile (e.g., `~/.bashrc`, `~/.zshrc`) to set the environment variables automatically.

### Cannot connect to docker daemon

- Verify that `dockerd.service` is running. If not, restart it with `dockerd.service restart`.
- You can also turn on or off dockerd service throuhgh magisk or kernelSU.

### Other Error & Bugs

You can explore to the issue tab, if there not exists, you can open issue, for help me resolve the problem, you can include fresh log.

1. Restart tailscaled with `dockerd.service restart`
2. Reproduce what are you doing which has problem.
3. Get log at `dockerd.service log run`
