#!/bin/sh
# shellcheck disable=SC1091
# shellcheck disable=SC1090

# Script to update the current vscodium's settings.json
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

# example ref'd from wikipeadia
while getopts ':s:p:e:w' opt; do
  case $opt in
    (s) settings_json_file="$OPTARG";;
    (p) project_dir="$OPTARG";;
    (e) env_file="$OPTARG";;
    (w) _write_to_file=true;;
    (:) : ;; # handled optional args (all args are!)
    (*) # print help
      cat >&2 <<HELP
Usage:
    $0 [-p PROJECT_PATH] [-s VSCODIUM_SETTINGS_JSON] [-e ENVIRONMENT_FILE] [-w]
    $0 [-s VSCODIUM_SETTINGS_FILE] [-e ENVIRONMENT_FILE] [-w] PROJECT_PATH

Build a new host configuration for remote-foss, based on the values in ENVIRONMENT_FILE and  VSCODIUM_SETTINGS_FILE. All aguments are optional.

To update your setting.json directly, use -w and provide -s VSCODIUM_SETTINGS_FILE
but watchout!

DEFAULTS:
    PROJECT_PATH           = \$(pwd)
    VSCODIUM_SETTINGS_JSON = "" (only print out the json)
    ENVIRONMENT_FILE       = .dev-env
HELP
      exit 0;;
  esac
done
shift "$((OPTIND - 1))"
# remaining is "$@"

: "${env_file:=.dev-env}"
: "${_write_to_file:=false}"

if [ -z "$project_dir" ]; then
  project_dir="${1:-"$(pwd)"}"
fi

# force `~` expansion (just to be safe)
project_dir="$(eval echo "$project_dir")"

which jq > /dev/null \
  || { echo "jq not found, please install it"; exit 1; }

. "$project_dir/$env_file" \
|| { echo "could not source $env_file, is it present in your project dir?"; exit 1; }

. "$project_dir/${codium_server_env_file:?Variable not set}" \
  || { echo "could not source '$codium_server_env_file',"\
      "is it present in your project dir?"\
      "(hint: run 'start.sh' once to generate the file)"\
    exit 1; }

# placing remote host in "$project_dir/.vscode/settings.json" currently doesn't function properly in remmote-foss
# force `~` expansion, again
settings_json_file="$(eval echo "${settings_json_file}")"
: "${host_name:="local-$(basename "${container_image:?Variable not set}"|tr ':' '-')"}"
: "${host_address:="127.0.0.1"}"

if "$_write_to_file"; then
  output_json_file="${settings_json_file:?Must provide path to settings.json (Hint: \`-h\' for help)}"
else
  output_json_file="/tmp/settings.json"
fi

if [ -z "$settings_json_file" ] || ! [ -s "$settings_json_file" ]; then
  echo "VSCode settings not found at'$settings_json_file'!"
  echo "{}" > "$output_json_file" || exit 1 # pull the break
elif "$_write_to_file"; then
  echo "Backing up '$settings_json_file'"
  cp  "$settings_json_file" "$settings_json_file.bak" || exit 1 # pull the break
fi

echo "[INFO]: Your configs are:"
(jq -r \
  --arg hName "$host_name" \
  --arg hAddr "${host_address}" \
  --arg hPort "${codium_server_external_port:?Variable not set}" \
  --arg hToken "${CONNECTION_TOKEN:-true}" \
  --arg fName "$(basename "$project_dir")" \
  --arg fPath "$project_dir" \
  '."remote.OSS.hosts" += [
  {
    "type": "manual",
    "name": $hName,
    "host": $hAddr,
    "port": ($hPort | tonumber),
    "connectionToken": $hToken,
    "folders": [
      {
        "name": $fName,
        "path": $fPath,
      }
    ]
  }]' "$settings_json_file" |\
  tee "$settings_json_file.tmp" | jq -C) ||\
  {
    echo error
    exit 1
  }

# not every elegant but whatever
mv "$settings_json_file.tmp" "$settings_json_file"
