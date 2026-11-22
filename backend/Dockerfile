# =============================================================================
# REKBER Backend - Production Multi-Stage Dockerfile (Prompt 20)
# =============================================================================
# Multi-stage build for optimal image size and security.
# Runs under non-root unprivileged user (nodejs, uid: 1001).
# NOTE: 'prisma migrate deploy' is NOT run in CMD/ENTRYPOINT, but as a separate
# release step in deployment pipelines.

# -----------------------------------------------------------------------------
# Stage 1: Build & Dependencies
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache openssl

# Install production dependencies first (layer caching)
COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci

# Generate Prisma Client binary for linux-musl
RUN npx prisma generate

# -----------------------------------------------------------------------------
# Stage 2: Production Runner
# -----------------------------------------------------------------------------
FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache openssl

ENV NODE_ENV=production

# Security: Create non-root unprivileged group and user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nodejs

# Copy dependencies and generated prisma client from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY package*.json ./
COPY src ./src

# Set ownership to unprivileged user
RUN chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5000

# Execute server directly without shell wrapper
CMD ["node", "src/server.js"]
