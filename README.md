# D.I.Y DevContainers!

Documenting my attempt of hacking together my own docker/podman based development environment in VSCodium. Based on the write up in [vscode-remote-oss](https://github.com/xaberus/vscode-remote-oss.git). This is intended to be an extension of their README.md, or in order words I will only bring up things that have existed in it.

> **Note**: For a VSCodium extension with proper devcontainer support, see [`devpodcontainers`](https://github.com/3timeslazy/vscodium-devpodcontainers).

## Prerequisites
- Remote-FOSS extension installed from [Open VSX](https://open-vsx.org/vscode/item?itemName=xaberus.remote-oss) (any extensions that enable the remote development API)
- Docker or Podman installed
- VSCodium RHEL server (Be mindful of the version of your VSCodium version as well as wheter your container are using `libmuls` or `gcc`)
- (optional) `fuse-overlayfs`

## Basic idea:
Make a script that:
  - Create a (temoprary) container.
  - Pass through:
    - the RHEL server executable
    - the plugin directory (to have project-scope plugins), as well as...
    - your particular project root directory.
  - publish the RHEL server port
  - start the RHEL server itself.

Also: generate the client side config (mainly a QoL thing).

I planned to have all the parameters to the script accessible and configurable via a [**`.dev-env`**](./.dev-env-TEMPLATE) file in one's project repositoty. This approach should mean that the configurations can be keep local even if everything is publiblish just by adding one line in `.gitignore`. To ensure that the values can be quicky overided in runtime I used POSIX shell's [parameter expansion](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html#tag_19_06_02) syntax:

```sh
: "${my_variable:=my default value}" # fall back to "my default value" if empty
: "${my_variable:?Variable not set!!}" # throws an error with content "Variable not set!!" if variable is empty
```

By default, similar to its client, the codium RHEL server install extensions at `$HOME/.vscodium-server/extensions`. Thus, to be able to only have the relevant extension accessible to each individual project and keep the server directory unmodified, simply mount the server directory anywhere other than at `$HOME/.vscodium-server/` (aka `/root/.vscodium-server/` in most container). And for persistence across temporary containers, simply bind a folder somewhere on your machine to said folder

```sh
podman run --rm -it \
    -v "/path/to/your/codium-server:/bin/vscodium-server" \
    -v "$(pwd)/.local/vscodium-server/:/root/.vscodium-server" \
    # Rest of the command
```

I, however, did not know this and had set aside an entire section in my script to mount the extension directory as an overlay file system and bind it to where the directory is supposed to be:

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
...which is unnessesary and a complete waste of resources unless you decided to mount the server dir dead on `$HOME/.vscodium-server`.

moving on to the server start script. Note how I set the host at `0.0.0.0` instead of `localhost` or `127.0.0.1`. I am not clear if it is a limitation with rootless podman or not but I can't connect to the server otherwise. I'd recommend using a connection token file placed in your container's home directory (which, again, is being passed along to the container).
```sh
#!/bin/sh
# shellcheck disable=SC1091

. "$HOME/.env" || exit 1;

"$(dirname "$0")/bin/codium-server" \
    --host 0.0.0.0 \
    --port "${REMOTE_PORT:?variable is empty.}" \
    --telemetry-level off \
    --connection-token-file "${CONNECTION_TOKEN_PATH:?variable is empty.}"
```


## Quick Start


## My attempt so far:

### Using the (outdated) demo:
1. Download and extract your VSCodium server
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
- [ ] cut out the unesseary stuff

> This README was modified in part using Claude 3.5 Haiku
