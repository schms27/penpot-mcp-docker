#!/bin/sh
set -e

MULTI_USER_FLAG=""
if [ "${MULTI_USER}" = "true" ]; then
  MULTI_USER_FLAG="--multi-user"
fi

MCP_PORT="${PENPOT_MCP_SERVER_PORT:-4401}"
INTERNAL_PORT=$((MCP_PORT + 1000))

echo "Starting Penpot MCP Server on internal port ${INTERNAL_PORT}..."
export PENPOT_MCP_SERVER_PORT=$INTERNAL_PORT
nohup node packages/server/dist/index.js ${MULTI_USER_FLAG} > /dev/null 2>&1 &
MCP_PID=$!

echo "Starting CORS proxy on port ${MCP_PORT}..."
nohup node -e "
const http = require('http');
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Accept, x-message-id, x-session-id'
};
http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders);
    res.end();
    return;
  }
  const proxyReq = http.request({
    hostname: '127.0.0.1',
    port: ${INTERNAL_PORT},
    path: req.url,
    method: req.method,
    headers: req.headers
  }, (proxyRes) => {
    const headers = { ...proxyRes.headers, ...corsHeaders };
    res.writeHead(proxyRes.statusCode, headers);
    proxyRes.pipe(res);
  });
  proxyReq.on('error', () => { res.writeHead(502); res.end('Proxy error'); });
  req.pipe(proxyReq);
}).listen(${MCP_PORT}, '0.0.0.0', () => console.log('CORS proxy listening on :${MCP_PORT}'));
" > /dev/null 2>&1 &
PROXY_PID=$!

unset PENPOT_MCP_SERVER_PORT

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

wait $MCP_PID $PROXY_PID $PLUGIN_PID
