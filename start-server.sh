#!/bin/sh
# shellcheck disable=SC1091

# Script to start the REH server within the container
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

. "$(dirname "$0")/.env" || exit 1;

"$(dirname "$0")/bin/codium-server" \
    --host 0.0.0.0 \
    --port "${REMOTE_PORT:?variable is empty.}" \
    --telemetry-level off \
    --connection-token "${CONNECTION_TOKEN:?variable is empty.}"
