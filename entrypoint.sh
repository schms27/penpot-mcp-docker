#!/bin/sh
set -e

MULTI_USER_FLAG=""
if [ "${MULTI_USER}" = "true" ]; then
  MULTI_USER_FLAG="--multi-user"
fi

# Plugin server must listen on all interfaces for Docker/self-hosted setups
export PENPOT_MCP_PLUGIN_SERVER_HOST="${PENPOT_MCP_PLUGIN_SERVER_HOST:-0.0.0.0}"

echo "Starting Penpot MCP Server on port ${PENPOT_MCP_SERVER_PORT:-4401}..."
node packages/server/dist/index.js ${MULTI_USER_FLAG} &
MCP_PID=$!

echo "Starting Penpot Plugin Server on port 4400..."
pnpm --filter mcp-plugin run start &
PLUGIN_PID=$!

wait $MCP_PID $PLUGIN_PID
