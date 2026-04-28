# Backend Dockerfile for Railway (Node 22)

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
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copy source
COPY backend/src ./src
COPY backend/scripts ./scripts
COPY backend/setup_uploads_directories.js ./setup_uploads_directories.js
COPY privacy_policy.html ./privacy_policy.html
COPY data_deletion_request.html ./data_deletion_request.html
COPY account_deletion_request.html ./account_deletion_request.html

# Create uploads directories directly in Dockerfile
RUN mkdir -p uploads/products uploads/branding && \
    echo "Created uploads directories"

# Health and runtime
# Railway typically sets PORT=8080
EXPOSE 8080
CMD ["npm", "start"]