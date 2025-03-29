# D.I.Y DevContainers!

This repo documents my journey of hacking together a Docker/Podman-based development environment in VSCodium without official devcontainer support. Consider this an extension of the approach described in [vscode-remote-oss](https://github.com/xaberus/vscode-remote-oss.git).

> **Note**: For a proper VSCodium extension with devcontainer support, see [`devpodcontainers`](https://github.com/3timeslazy/vscodium-devpodcontainers).

## Prerequisites
- Remote-FOSS extension from [Open VSX](https://open-vsx.org/vscode/item?itemName=xaberus.remote-oss)
- Docker or Podman
- VSCodium RHEL server (matching your VSCodium version and container's libc implementation)
- (optional) `fuse-overlayfs`

## The General Idea

The approach is straightforward:
- Create a container
- Pass through the RHEL server executable, plugin directory, and project root
- Publish the RHEL server port
- Start the RHEL server
- Configure the client to connect to this server

## What Actually Works

For anyone wanting to skip my learning process, here's the key insight:

By default, the VSCodium RHEL server installs extensions at `$HOME/.vscodium-server/extensions`. To isolate extensions per project, simply mount the server directory anywhere *except* at `$HOME/.vscodium-server/` and provide a project-specific extensions directory:

```sh
podman run --rm -it \
    -v "/path/to/your/codium-server:/bin/vscodium-server" \
    -v "$(pwd)/.local/vscodium-server/:/root/.vscodium-server" \
    # Rest of the command
```

For the server startup, set the host to `0.0.0.0` (not `localhost` or `127.0.0.1`) and use a connection token file:

```sh
#!/bin/sh
. "$HOME/.env" || exit 1;

"$(dirname "$0")/bin/codium-server" \
    --host 0.0.0.0 \
    --port "${REMOTE_PORT:?variable is empty.}" \
    --telemetry-level off \
    --connection-token-file "${CONNECTION_TOKEN_PATH:?variable is empty.}"
```

I've made all parameters configurable via a [`.dev-env`](./.dev-env-TEMPLATE) file, using POSIX shell's parameter expansion for defaults:

```sh
: "${my_variable:=my default value}" # falls back to default if empty
: "${my_variable:?Variable not set!!}" # throws error if empty
```

## The OverlayFS Saga

Remember when I said that your plugin is automatically separated when you mount the RHEL's server folder anywhere **other** than `$HOME/.vscodium-server`? I didn't know that. Thus I wasted my time and CPU cycles mounting the Codium server's extensions directory using an overlay filesystem:

```bash
ext_overlayFS_lower_paths="$codium_server_path/$codium_server_extension_dir:$project_extension_overlayFS_lower_dir_paths"
ext_overlayFS_upper_path="$project_path/$project_extension_overlayFS_upper_dir"
ext_overlayFS_work_path="$project_path/$project_extension_overlayFS_work_dir"
ext_overlayFS_mount_point="/tmp/$project_extension_overlayFS_mount_dir_prefix-$(rand_hex 4)"

overlayfs_cleanup(){
  echo "Unmounting '$ext_overlayFS_mount_point'"
  fusermount -u "$ext_overlayFS_mount_point" &&\
  rmdir -v "$ext_overlayFS_mount_point"
}

fuse-overlayfs\
  -o lowerdir="$ext_overlayFS_lower_paths"\
  -o upperdir="$ext_overlayFS_upper_path"\
  -o workdir="$ext_overlayFS_work_path"\
  "$ext_overlayFS_mount_point" \
    && echo "Mounted overlay filesystem for project's extensions at '$ext_overlayFS_mount_point'"\
    || exit 1

# [...]
podman run --rm -it \
    -v "/path/to/my/codium-server:/bin/codium-server" \
    -v "$ext_overlayFS_mount_point:/bin/.codium-server" \
    # Rest of the command

# after the container exit
overlayfs_cleanup
```

I included this here mainly because I had put way too much effort for this to be buried 6 feet under (and who knows? Maybe you ARE planning to mount the server directory dead on `$HOME/.vscodium-server` :3)

## Running the demo

1. Download and extract your VSCodium server
   - Copy `server-server.sh` to the extracted directory
   - Rename the `extensions` folder to `_extensions` (prevents server from using these by default)

2. Prepare your project folder
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

4. Start your dev environment
   - Run `start.sh`
   - The script will generate a connection token and start the server

5. Configure Remote Connection
   - Run `add_remote_oss_hosts_conf.sh` to generate connection config
   - Optional: Use `-p ~/path/to/.vscode/profile/.../settings.json` to specify location
   - Copy the generated config to your settings file

   Alternatively, update settings directly:
   ```
   ./add_remote_oss_hosts_conf.sh -w -p ~/path/to/.vscode/profile/.../settings.json
   ```

6. Connect using the Remote-FOSS extension

## TODO
- [ ] Clean up the unnecessary parts in the script (the eternal todo item)
- [x] Improve documentation (to be actually presentable)(using Claude)

> This README was modified with help from the Claude LLM family
