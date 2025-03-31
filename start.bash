#!/bin/bash
# shellcheck disable=SC1091,SC1091,SC2154

# Script to start the REH server container
# Copyright (C) 2025  qjtdsqqm94akkyysgjdqo3hx1jn6l17
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser Public License for more details.
#
# You should have received a copy of the GNU Lesser Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

readonly e="$(printf '\033[1m[\033[5m\033[31mERROR\033[39m\033[25m]\033[0m')"
readonly i="$(printf '\033[1m[\033[36mINFO\033[39m]\033[0m')"

CURR_DIR="$(pwd)"
: "${run_cmd:=sh "/bin/codium-server/start-server.sh"}"
# shellcheck source-path=./.dev-env-TEMPLATE
! [ -r "$(dirname "$0")/.dev-env" ] || . "$(dirname "$0")/.dev-env"
. "$CURR_DIR/.dev-env" || {
  echo "$e Please make a file called '.dev-env' with the content of '.dev-env-TEMPLATE'"
  exit 1
}

: "${container_image:?$e Container image name not specified, set it in .dev-env}"
: "${codium_server_path:?$e Path not defined, set it in .dev-env}"

_missing_var=false
# Check if variables are present
for var in \
  "container_image"\
  "codium_server_path"\
  "container_prog"\
  "project_path"\
  "diy_devcon_base_path"\
  "project_home_path"\
  "codium_server_token_file"\
  "codium_server_env_file"\
  "codium_server_internal_port"\
  "codium_server_external_port"\
  "container_home_path"\
  "container_codium_server_token_file"\
  "container_codium_server_path"\
  "_print_configs"\
  "_permanent_container"
do
  # put this in a subshell so we don't get `exit 1`'d
  (eval : "\${$var:?Variable not set}") || _missing_var=true
done

if "$_missing_var"; then
  echo -e "\n$e The above variables is NOT defined."\
    "Pls make sure that '.dev-env' follows the TEMPLATE"
  echo "$i Script will now exit."
  exit 1
fi

unset _missing_var

rand_hex(){
  local length="${1:-8}" # default length is 8 bytes (16 characters)
  hexdump -n "$length" -ve '"%x"' < /dev/urandom
}

mkdir -pv "$project_home_path"


codium_server_env_file="$project_path/${codium_server_env_file}"

# TODO: random name gen
#   shuf -n 30 -e $(grep -vE "^.+(ty|ed|ive|'s)$" /usr/share/dict/words)
# shuf -n 30 -e $(grep -E "^[[:lower:]]+(ry|al|ile|esque|ish|like|ful|ive|able|ible|less|ous|nite|ed)$" /usr/share/dict/words)

if ! [ -s "$codium_server_token_file" ]; then
  echo "$i connection token file @ '$codium_server_token_file' not found!"\
    "generating a new one..."
  CONNECTION_TOKEN="$(rand_hex 32 | sha512sum | cut -d ' ' -f 1 )"
  # remove any line with CONNECTION_TOKEN, then add new CONNECTION_TOKEN=... line
      echo -n "$CONNECTION_TOKEN" > "$codium_server_token_file"
    _print_configs=true
fi
# shellcheck disable=SC1090
if ! source "$codium_server_env_file"; then
  echo "$i unable to source '$codium_server_env_file'!"\
    "regenerating file..."
  cp "$codium_server_env_file" "$codium_server_env_file.bak" &2>/dev/null
  echo -e \
    "REMOTE_PORT='$codium_server_internal_port'"\
    "\nTOKEN_FILE='$container_codium_server_token_file'" > "$codium_server_env_file"
else
  if [ -z "$TOKEN_FILE" ] ||\
    [ "$TOKEN_FILE" != "$container_codium_server_token_file" ];
  then
    echo "$i Container token path not defined or mismatch with what's in '.dev-env'!" \
      "Updating the file..."
    TOKEN_FILE="$(rand_hex 32 | sha512sum | cut -d ' ' -f 1 )"
    # remove any line with TOKEN_FILE, then add new TOKEN_FILE=... line
    sed -i'.bak' "$codium_server_env_file" \
      -e  '/^TOKEN_FILE.*$' \
      -e "\$aTOKEN_FILE=${container_codium_server_token_file}"
    _print_configs=true
  fi

  if [ -z "$REMOTE_PORT" ] ||\
    [ "$REMOTE_PORT" != "$codium_server_internal_port" ]
  then
    echo "$i Port not defined or mismatch with what's in '.dev-env'!"\
      "Updating the file..."

    sed -i'.bak' "$codium_server_env_file" \
      -e  '/^REMOTE_PORT.*$' \
      -e "\$aREMOTE_PORT=${codium_server_internal_port}"
  fi
fi

if "$_print_configs"; then
  echo -e "\n======== CURRENT CONFIGS ========"
  echo -e "PORT:\t $codium_server_external_port"
  echo -e "PATH:\t $(pwd)"
  echo -e "TOKEN:\t $CONNECTION_TOKEN"
  echo -e "=================================\n$i (script will pause for a bit)"
  sleep 5 # pause so the user don't miss the config
fi


"$container_prog" run --rm -it -v "$(pwd):$(pwd)" \
  -v "$project_home_path:$container_home_path"\
  -v "$codium_server_path:$container_codium_server_path"\
  -p "$codium_server_external_port:$codium_server_internal_port"\
  "${container_extra_args[@]}" \
  "$container_image"\
  sh -c "${run_cmd}"
