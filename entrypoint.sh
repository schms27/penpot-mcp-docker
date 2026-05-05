#!/bin/sh
set -e

MULTI_USER_FLAG=""
if [ "${MULTI_USER}" = "true" ]; then
  MULTI_USER_FLAG="--multi-user"
fi

echo "Starting Penpot MCP Server on port ${PENPOT_MCP_SERVER_PORT:-4401}..."
nohup node packages/server/dist/index.js ${MULTI_USER_FLAG} > /dev/null 2>&1 &
MCP_PID=$!

echo "Starting Penpot Plugin Server on port 4400..."
nohup node -e "
const http = require('http');
const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, 'packages/plugin/dist');
const mime = {
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.html': 'text/html',
  '.json': 'application/json',
  '.jpg': 'image/jpeg',
  '.png': 'image/png'
};
http.createServer((req, res) => {
  let file = req.url === '/' ? '/index.html' : req.url;
  const fp = path.join(dir, file);
  if (!fs.existsSync(fp)) { res.writeHead(404); res.end('Not found'); return; }
  const ext = path.extname(fp);
  res.writeHead(200, {
    'Content-Type': mime[ext] || 'application/octet-stream',
    'Access-Control-Allow-Origin': '*'
  });
  fs.createReadStream(fp).pipe(res);
}).listen(4400, '0.0.0.0', () => console.log('Plugin server listening on :4400'));
" > /dev/null 2>&1 &
PLUGIN_PID=$!

wait $MCP_PID $PLUGIN_PID
