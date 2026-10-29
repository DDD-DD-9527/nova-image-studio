FROM node:24-bookworm-slim AS frontend-builder

WORKDIR /app

COPY package.json package-lock.json ./
COPY frontend/package.json frontend/package-lock.json ./frontend/
# Zeabur injects NODE_ENV=production into build steps. Keep TypeScript,
# Tailwind and other devDependencies available to the frontend compiler.
RUN cd frontend && npm ci --include=dev --no-audit --no-fund
COPY frontend/ ./frontend/
RUN cd frontend && npm run build

FROM node:24-bookworm-slim AS backend-deps

WORKDIR /app/backend

# better-sqlite3 需要在安装阶段使用 python3、make、g++
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY backend/package.json backend/package-lock.json ./

RUN npm ci --omit=dev \
  && apt-get purge -y --auto-remove python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

FROM node:24-bookworm-slim AS production

WORKDIR /app

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0 PORT=3000 \
    NOVA_TASK_DB=/data/nova-tasks.sqlite \
    NOVA_IMAGE_DIR=/data/nova-images \
    TZ=Asia/Shanghai

COPY backend/ ./backend/
COPY --from=backend-deps /app/backend/node_modules/ ./backend/node_modules/
COPY --from=frontend-builder /app/frontend/out/ ./frontend/out/

RUN mkdir -p /data

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/api/nova/queue-status').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "backend/server.js"]
