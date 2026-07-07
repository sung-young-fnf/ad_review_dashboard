# s3gate Frontend (Next.js 16)
# Production Dockerfile (Monorepo multi-stage)

# ─── Deps ───
FROM node:20-alpine AS deps
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@9.14.2 --activate

# Monorepo workspace
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY apps/s3gate/frontend/package.json ./apps/s3gate/frontend/

# pnpm store cache
RUN --mount=type=cache,id=pnpm-fe,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# ─── Builder ───
FROM node:20-alpine AS builder
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@9.14.2 --activate

COPY --from=deps /app ./
COPY apps/s3gate/frontend/ ./apps/s3gate/frontend/
COPY packages/ ./packages/

WORKDIR /app/apps/s3gate/frontend

# OOM 방지: 힙 확장
RUN NODE_OPTIONS="--max-old-space-size=8192" pnpm build

# ─── Runner ───
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# standalone (모노레포 디렉토리 구조 유지)
COPY --from=builder --chown=nextjs:nodejs /app/apps/s3gate/frontend/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/s3gate/frontend/.next/static ./apps/s3gate/frontend/.next/static

# public (standalone 미포함)
COPY --from=builder --chown=nextjs:nodejs /app/apps/s3gate/frontend/public ./apps/s3gate/frontend/public

USER nextjs

EXPOSE 3100

ENV PORT=3100
ENV HOSTNAME="0.0.0.0"

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3100/api/health || exit 1

CMD ["node", "apps/s3gate/frontend/server.js"]
