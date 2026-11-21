# Production image for the Brunchy backend. Build from the REPOSITORY ROOT (it needs database/ too):
#   docker build -f backend/Dockerfile -t brunchy-api .
# deploy/docker-compose.prod.yml does this for you.

# ---- 1. Build: install everything, compile TypeScript to dist/ ----
FROM node:22-alpine AS build
WORKDIR /app/backend
COPY backend/package.json backend/package-lock.json ./
RUN npm ci
COPY backend/tsconfig.json backend/tsconfig.build.json ./
COPY backend/src ./src
RUN npm run build

# ---- 2. Run: production dependencies + compiled code + SQL migrations ----
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app/backend
COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/backend/dist ./dist
# The migration runner reads ../database (repo root) relative to dist/db.
COPY database /app/database
USER node
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:4000/api/v1/health || exit 1
# Apply any new database migrations, then start the API (Express + Socket.IO + background jobs).
CMD ["sh", "-c", "node dist/db/migrate.js migrate && exec node dist/server.js"]
