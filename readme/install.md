# Install mAIcro

mAIcroverse runs alongside a local mAIcro installation. Install and start mAIcro with Docker before setting up the learning instance.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) is installed and running.
- The mAIcro container is running.

Check the running containers:

```bash
docker ps
```

The output should include a container named `maicro`. If Docker is not available or the container is missing, install mAIcro first.

## Install mAIcro

### macOS, Linux, or WSL

```bash
curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/run.sh | sh
```

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/run.ps1 | iex
```

See [the installer README](../maicro-install/README.md) for custom data directories, port configuration, updates, and removal.

## Next Step

After the container is running, follow [Set up mAIcroverse](maicroverse.md).
