# Backend Dockerfile for Railway (Node 22)
# Switch from deprecated Nixpacks builder to Dockerfile for deterministic builds

FROM node:22-bookworm-slim AS base
ENV NODE_ENV=production \ 
    HOST=0.0.0.0 \ 
    PORT=3000

# Install minimal build dependencies for native addons (e.g., mysql2)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps first (use lockfile if present)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source
COPY src ./src
COPY setup_uploads_directories.js ./
# If you serve any static web content from ../web-app in production, mount it at runtime or copy it here.

# Health and runtime
# Railway typically sets PORT=8080
EXPOSE 8080

# Container-level healthcheck to complement Railway HTTP healthchecks
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 8080) + '/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "--dns-result-order=ipv4first", "src/index.js"]
