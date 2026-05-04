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

# Logs directory writable by non-root user
RUN mkdir -p /app/logs && chown penpot:penpot /app/logs

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

USER penpot

ENTRYPOINT ["dumb-init", "--", "/app/entrypoint.sh"]
