# {{APP_NAME}} Backend (NestJS + Prisma)
# Production Dockerfile (Monorepo multi-stage)

# ─── Deps ───
FROM node:20-alpine AS deps
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@9.14.2 --activate

# Monorepo workspace
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY apps/{{APP_NAME}}/backend/package.json ./apps/{{APP_NAME}}/backend/

# pnpm store cache로 재빌드 시 다운로드 최소화
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# ─── Builder ───
FROM node:20-alpine AS builder
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@9.14.2 --activate

COPY --from=deps /app ./
COPY apps/{{APP_NAME}}/backend/ ./apps/{{APP_NAME}}/backend/
COPY packages/ ./packages/

WORKDIR /app/apps/{{APP_NAME}}/backend

# Prisma generate (custom output → src/generated/prisma-client)
RUN if [ -f "prisma/schema.prisma" ]; then npx prisma generate; fi

# NestJS build
RUN pnpm build

# Prisma engine binary (tsc는 .node 미포함)
RUN mkdir -p dist/src/generated/prisma-client/ && \
    cp src/generated/prisma-client/libquery_engine* dist/src/generated/prisma-client/ 2>/dev/null || true

# pnpm deploy: symlink 해소된 독립 node_modules
WORKDIR /app
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm deploy --filter=apps/{{APP_NAME}}/backend /app/deploy 2>/dev/null || \
    cp -r /app/apps/{{APP_NAME}}/backend/node_modules /app/deploy/node_modules

# .prisma/client 런타임 복사 (custom output 경로 동기화)
RUN mkdir -p /app/deploy/node_modules/.prisma/client && \
    cp -r /app/apps/{{APP_NAME}}/backend/src/generated/prisma-client/* \
          /app/deploy/node_modules/.prisma/client/ 2>/dev/null || true

# ─── Runner ───
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs

COPY --from=builder --chown=nestjs:nodejs /app/deploy/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/apps/{{APP_NAME}}/backend/package.json ./package.json
COPY --from=builder --chown=nestjs:nodejs /app/apps/{{APP_NAME}}/backend/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/apps/{{APP_NAME}}/backend/prisma ./prisma

USER nestjs

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

CMD ["node", "dist/src/main.js"]
