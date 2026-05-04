# ============================================================
# Stage 1: Install & Build @penpot/mcp from npm
# ============================================================
FROM node:22-slim AS builder

WORKDIR /build

# Install the official Penpot MCP package
RUN npm pack @penpot/mcp@stable && tar xzf penpot-mcp-*.tgz --strip-components=1 && rm penpot-mcp-*.tgz

# Restore pnpm-lock.yaml (shipped as pnpm-lock.dist.yaml in npm package)
RUN [ -f pnpm-lock.dist.yaml ] && cp pnpm-lock.dist.yaml pnpm-lock.yaml || true

# Enable corepack and install pnpm (requires package.json with packageManager field)
RUN corepack enable && corepack install

# Install all workspace dependencies (common + server + plugin)
RUN pnpm install

# Build all components (mcp-common, mcp-server, mcp-plugin)
RUN pnpm run build

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1001 penpot && useradd -u 1001 -g penpot -m penpot

WORKDIR /app

# Copy entire built package from builder (includes node_modules, dist, static, data)
COPY --from=builder /build/ .

# Install pnpm in runtime (needed for plugin server)
RUN corepack enable

# Server resolves data/ and static/ relative to process.cwd()
RUN ln -s /app/packages/server/dist/data /app/data \
    && ln -s /app/packages/server/dist/static /app/static

# Logs directory writable by non-root user
RUN mkdir -p /app/logs && chown penpot:penpot /app/logs

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# ── Environment defaults ──────────────────────────────────────
ENV PENPOT_MCP_SERVER_LISTEN_ADDRESS=0.0.0.0
ENV PENPOT_MCP_SERVER_ADDRESS=localhost
ENV PENPOT_MCP_SERVER_PORT=4401
ENV PENPOT_MCP_WEBSOCKET_PORT=4402
ENV PENPOT_MCP_REPL_PORT=4403
ENV PENPOT_MCP_PLUGIN_SERVER_HOST=0.0.0.0
ENV PENPOT_MCP_LOG_LEVEL=info
ENV PENPOT_MCP_LOG_DIR=/app/logs
ENV PENPOT_MCP_REMOTE_MODE=false

EXPOSE 4400 4401 4402 4403

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.PENPOT_MCP_SERVER_PORT||4401)+'/').then(()=>process.exit(0)).catch(()=>process.exit(1))"

USER penpot

ENTRYPOINT ["dumb-init", "--", "/app/entrypoint.sh"]
