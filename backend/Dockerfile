# Multi-stage build para imagem mínima de produção.
# Não obrigatório para Render (usa node detect), mas torna o backend portátil
# para Fly.io, AWS, Docker local, etc.

# ---------- Build stage ----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

# ---------- Runtime stage ----------
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Usuário não-root para segurança
RUN addgroup -S app && adduser -S app -G app

COPY --from=deps /app/node_modules ./node_modules
COPY --chown=app:app package.json ./
COPY --chown=app:app src ./src

USER app
EXPOSE 3000

# Healthcheck nativo do Docker (em pé com cluster orchestrators tipo Compose/K8s)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:${PORT:-3000}/api/health || exit 1

CMD ["node", "src/server.js"]
