# {{APP_NAME}} Frontend (Next.js 16)
# Production Dockerfile (Monorepo multi-stage)

# ─── Deps ───
FROM node:20-alpine AS deps
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@9.14.2 --activate

# Monorepo workspace
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY apps/{{APP_NAME}}/frontend/package.json ./apps/{{APP_NAME}}/frontend/

# pnpm store cache
RUN --mount=type=cache,id=pnpm-fe,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# ─── Builder ───
FROM node:20-alpine AS builder
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@9.14.2 --activate

COPY --from=deps /app ./
COPY apps/{{APP_NAME}}/frontend/ ./apps/{{APP_NAME}}/frontend/
COPY packages/ ./packages/

WORKDIR /app/apps/{{APP_NAME}}/frontend

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
COPY --from=builder --chown=nextjs:nodejs /app/apps/{{APP_NAME}}/frontend/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/{{APP_NAME}}/frontend/.next/static ./apps/{{APP_NAME}}/frontend/.next/static

# public (standalone 미포함)
COPY --from=builder --chown=nextjs:nodejs /app/apps/{{APP_NAME}}/frontend/public ./apps/{{APP_NAME}}/frontend/public

USER nextjs

EXPOSE {{FRONTEND_PORT}}

ENV PORT={{FRONTEND_PORT}}
ENV HOSTNAME="0.0.0.0"

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:{{FRONTEND_PORT}}/api/health || exit 1

CMD ["node", "apps/{{APP_NAME}}/frontend/server.js"]
