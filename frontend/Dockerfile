# ── Stage 1: dependency install + build ────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first (layer-cache friendly)
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY pages/ ./pages/
# Copy public dir if it exists (optional static assets)
COPY public* ./public/

# NEXT_PUBLIC_API_URL must be provided at build time so Next.js can inline it.
# We pass a placeholder here; the real value is injected via runtime env var
# using Next.js runtime config (next.config.js publicRuntimeConfig approach
# is NOT used here — we rely on the env var being present when `next start` runs,
# which works because SSR reads process.env at request time, not build time).
ARG NEXT_PUBLIC_API_URL=""
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

RUN npm run build

# ── Stage 2: production runtime ────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only what next start needs
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/public* ./public/

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 3000

# NEXT_PUBLIC_API_URL injected at container start by ECS task def / Cloud Run --set-env-vars
ENV NEXT_PUBLIC_API_URL=""

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -qO- http://localhost:3000/ || exit 1

CMD ["npm", "run", "start"]
