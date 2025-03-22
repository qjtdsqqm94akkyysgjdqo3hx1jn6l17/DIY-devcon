#!/bin/bash
# shellcheck disable=SC1091,SC1091,SC2154

CURR_DIR="$(pwd)"
: "${run_cmd:=sh "/bin/codium-server/start-server.sh"}"
# shellcheck source-path=./.dev-env-TEMPLATE
! [ -r "$(dirname "$0")/.dev-env" ] || . "$(dirname "$0")/.dev-env"
. "$CURR_DIR/.dev-env" || {
  echo "Please make a file called '.dev-env' with the content of '.dev-env-TEMPLATE'"
  exit 1
}

: "${container_image:?Container image name not specified, set it in .dev-env}"
: "${codium_server_path:?Path not defined, set it in .dev-env}"


rand_hex(){
  local length="${1:-8}" # default length is 8 bytes (16 characters)
  hexdump -n "$length" -ve '"%x"' < /dev/urandom
}

overlayfs_cleanup(){
  echo "Unmounting '$ext_overlayFS_mount_point'"
  fusermount -u "$ext_overlayFS_mount_point" &&\
  rmdir -v "$ext_overlayFS_mount_point"
}

ext_overlayFS_lower_paths="$codium_server_path/$codium_server_extension_dir:$project_extension_overlayFS_lower_dir_paths"
ext_overlayFS_upper_path="$project_path/$project_extension_overlayFS_upper_dir"
ext_overlayFS_work_path="$project_path/$project_extension_overlayFS_work_dir"
ext_overlayFS_mount_point="/tmp/$project_extension_overlayFS_mount_dir_prefix-$(rand_hex 4)"

echo "Creating directory(ies)"
for path in \
  "$ext_overlayFS_lower_paths"\
  "$ext_overlayFS_upper_path"\
  "$ext_overlayFS_work_path"\
  "$ext_overlayFS_mount_point"
do
  mkdir -pv "$path"
done

fuse-overlayfs\
  -o lowerdir="$ext_overlayFS_lower_paths"\
  -o upperdir="$ext_overlayFS_upper_path"\
  -o workdir="$ext_overlayFS_work_path"\
  "$ext_overlayFS_mount_point" \
    && echo "Mounted overlay filesystem for project's extensions at '$ext_overlayFS_mount_point'"\
    || exit 1

container_env_path="$project_path/${codium_server_env_file}"
# shellcheck disable=SC1090
if ! source "$container_env_path"; then
  echo "unable to source .container-env! regenerating file with a new token..."
  cp "$container_env_path" "$container_env_path.bak"
  CONNECTION_TOKEN="$(rand_hex 32 | sha512sum | cut -d ' ' -f 1 )"
  echo -e \
    "REMOTE_PORT='$codium_server_internal_port'"\
    "\nCONNECTION_TOKEN='$CONNECTION_TOKEN'" > "$container_env_path"
else

  if [ -z "$CONNECTION_TOKEN" ]; then
    echo "connection token not found! generating a new one & updating the file..."
    CONNECTION_TOKEN="$(rand_hex 32 | sha512sum | cut -d ' ' -f 1 )"
    # remove any line with CONNECTION_TOKEN, then add new CONNECTION_TOKEN=... line
    sed -i'.bak' "$container_env_path" \
      -e  '/^CONNECTION_TOKEN.*$' \
      -e "\$aCONNECTION_TOKEN=${CONNECTION_TOKEN}"
    _print_configs=true
  fi

  if [ -z "$REMOTE_PORT" ] ||\
    [ "$REMOTE_PORT" != "$codium_server_internal_port" ]
  then
    echo "Port mismatch! updating the file with value from 'codium_server_internal_port'..."

    sed -i'.bak' "$container_env_path" \
      -e  '/^REMOTE_PORT.*$' \
      -e "\$aREMOTE_PORT=${codium_server_internal_port}"
  fi
fi

if "$_print_configs"; then
  echo -e "\n======== CURRENT CONFIGS ========"
  echo -e "PORT:\t $codium_server_external_port"
  echo -e "PATH:\t $(pwd)"
  echo -e "TOKEN:\t $CONNECTION_TOKEN"
  echo -e "=================================\n(script will pause for a bit)"
  sleep 5 # pause so the user don't miss the config
fi


"$container_prog" run --rm -it -v "$(pwd):$(pwd)" \
  -v "$ext_overlayFS_mount_point:/bin/codium-server/extensions"\
  -v "$codium_server_path:/bin/codium-server/"\
  -v "$container_env_path:/bin/codium-server/.env"\
  -p "$codium_server_external_port:$codium_server_internal_port"\
  "${container_extra_args[@]}" \
  "$container_image"\
  sh -c "${run_cmd}"

overlayfs_cleanup
