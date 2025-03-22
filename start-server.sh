#!/bin/sh
# shellcheck disable=SC1091

. "$(dirname "$0")/.env" || exit 1;

"$(dirname "$0")/bin/codium-server" \
    --host 0.0.0.0 \
    --port "${REMOTE_PORT:?variable is empty.}" \
    --telemetry-level off \
    --connection-token "${CONNECTION_TOKEN:?variable is empty.}"
