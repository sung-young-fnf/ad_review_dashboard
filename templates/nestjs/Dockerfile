FROM node:20-slim AS base
RUN corepack enable pnpm

WORKDIR /app

# Dependencies
COPY package.json pnpm-lock.yaml* ./
COPY prisma/ ./prisma/
RUN pnpm install --frozen-lockfile
RUN pnpm prisma generate

# Build
COPY . .
RUN pnpm build

# Production
FROM node:20-slim AS production
RUN corepack enable pnpm
WORKDIR /app

COPY --from=base /app/dist ./dist
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/package.json ./
COPY --from=base /app/prisma ./prisma

EXPOSE 8000
CMD ["node", "dist/main"]
