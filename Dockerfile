# Use Node.js 18 as base
FROM node:18

# Install Flutter
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Download and install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"

# Pre-download Flutter artifacts
RUN flutter precache

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY backend/package*.json ./backend/

# Install dependencies
RUN npm install
RUN cd backend && npm install

# Copy source code
COPY . .

# Build Flutter web app
RUN cd frontend && flutter clean && flutter pub get && flutter build web --release --web-renderer canvaskit

# Create uploads directories
RUN mkdir -p backend/uploads/products backend/uploads/branding

# Expose port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
