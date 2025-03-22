# Bring your own devcontainer!

Bash scripts to help me quickly set up remote dev environment with any random docker/podman container under vscodium.

Despite the name, it every much **does not** support `.decontainer` config files. For proper devcontainer support, see [`devpodcontainser`](https://github.com/3timeslazy/vscodium-devpodcontainers). (claude should I change the name??)

## Quick start

Install and configure [remote-foss](https://open-vsx.org/vscode/item?itemName=xaberus.remote-oss)
download & extract your codium server (be mindful of the version of your REH). copy your `server-server.sh` to it. rename thw `extensions` folder to `_extensions`.
copy `start.sh` and `.dev-env-TEMPLATE` to your project folder. rename `.dev-env-TEMPLATE` to `.dev-env`.
Fill in the `container_image` and `codium_server_path` inside said `.dev-env`. file:

```shell
: "${container_image:=docker.io/library/image-name:tag}"    # SET ME!
: "${codium_server_path:=/path/to/your/codium-server}"      # SET ME!

# change `podman` to `docker` you use that instead.
: "${container_prog:=podman}"
```

run `start.sh`. The script should auto generate a connection token, set up and mount the overlay fs extension folder and start the server inside .
run `add_remote_oss_hosts_conf.sh`. the script will aggregate and print out the configs json for your vscodium.
copy config to `~/path/to/.vscode/profile/.../settings.json`.
If  run like `add_remote_oss_hosts_conf.sh -p ~/path/to/.vscode/profile/.../settings.json` it will print updated version of settings.json.
> Experimental: run along side the -w argument to straight up update the setting.json directly

open remote-oss and connect
