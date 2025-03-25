# Bring Your Own DevContainer!

Bash scripts to quickly set up a remote development environment with any Docker or Podman container in VSCodium. Very not suited for any serious work probably.

> **Note**: Depiste the name, this project does not currently support `.devcontainer` configuration files. For a VSCodium with proper devcontainer support, see [`devpodcontainers`](https://github.com/3timeslazy/vscodium-devpodcontainers).

## Quick Start

### Prerequisites
- Remote-FOSS extension installed from [Open VSX](https://open-vsx.org/vscode/item?itemName=xaberus.remote-oss)
- Docker or Podman installed

### Setup Steps

1. Download and extract your VSCodium server
   > Be mindful of the version & architechture of your server
   - Copy `server-server.sh` to the extracted directory
   - Rename the `extensions` folder to `_extensions`

2. Prepare Project Folder
   - Copy `start.sh` and `.dev-env-TEMPLATE` to your project
   - Rename `.dev-env-TEMPLATE` to `.dev-env`

3. Configure `.dev-env`
   ```shell
   # Set your container image
   : "${container_image:=docker.io/library/image-name:tag}"

   # Set path to your VSCodium server
   : "${codium_server_path:=/path/to/your/codium-server}"

   # Choose container runtime (docker or podman)
   : "${container_prog:=podman}"
   ```

4. Start Development Environment
   - Run `start.sh`
     - Automatically generates a connection token
     - Sets up and mounts the overlay filesystem for extensions
     - Starts the server

5. Configure Remote Connection
   - Run `add_remote_oss_hosts_conf.sh`
     - Generates VSCodium connection configuration
     - Optional: Run with `-p ~/path/to/.vscode/profile/.../settings.json`
   - Copy the generated config to `~/path/to/.vscode/profile/.../settings.json`

   Experimental: Directly update settings.json
   ```
   # Update settings file in-place
   ./add_remote_oss_hosts_conf.sh -w -p ~/path/to/.vscode/profile/.../settings.json
   ```

6. Connect
   - Open Remote-FOSS extension
   - Connect to the remote host

## Experimental Features
- Use `-w` flag to directly write to settings.json

## TODO
- [ ] idk

> This README was modified in part using Claude 3.5 Haiku
