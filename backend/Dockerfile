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
  && rm -rf /var/libapt/lists/*

WORKDIR /app

# Install deps first (use lockfile if present)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source
COPY src ./src

# Create uploads directories directly in Dockerfile
RUN mkdir -p uploads/products uploads/branding && \
    echo "Created uploads directories"

# Health and runtime
# Railway typically sets PORT=8080
EXPOSE 8080
CMD ["npm", "start"]