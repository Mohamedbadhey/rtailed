# Root Dockerfile for Railway to build only the backend app
# Uses Node 22 slim image and installs only production deps

FROM node:22-bookworm-slim AS base
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000

# Minimal dependencies for native modules (e.g., mysql2)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

# Work inside backend folder
WORKDIR /app/backend

# Install dependencies using lockfile when available
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copy backend source only
COPY backend/. ./

# Ensure uploads dirs exist at runtime (script is idempotent)
# Do NOT start the server during build.

# Railway typically sets PORT=8080
EXPOSE 8080

# Start the server at runtime; wait_for_db is part of the start script
CMD ["npm", "start"]
