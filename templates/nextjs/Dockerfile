FROM node:20-slim AS base
RUN corepack enable pnpm

WORKDIR /app

# Dependencies
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

# Build
COPY . .
RUN pnpm build

# Production
FROM node:20-slim AS production
WORKDIR /app

COPY --from=base /app/.next/standalone ./
COPY --from=base /app/.next/static ./.next/static
COPY --from=base /app/public ./public

ENV PORT={{FRONTEND_PORT}}
EXPOSE {{FRONTEND_PORT}}
CMD ["node", "server.js"]
