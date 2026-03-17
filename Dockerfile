# =========================
# STAGE 1 - BUILD
# =========================
FROM node:20-alpine AS builder

RUN apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

WORKDIR /evolution

COPY package*.json ./
COPY tsconfig.json ./
COPY tsup.config.ts ./

RUN npm ci --silent

COPY src ./src
COPY public ./public
COPY prisma ./prisma
COPY manager ./manager
COPY runWithProvider.js ./
COPY Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN echo "DATABASE_PROVIDER=sqlite" > .env && \
    echo "DATABASE_URL=file:./dev.db" >> .env && \
    ./Docker/scripts/generate_database.sh && \
    rm -f .env

RUN npm run build
RUN npm install

# =========================
# STAGE 2 - FINAL
# =========================
FROM node:20-alpine AS final

RUN apk add --no-cache tzdata ffmpeg bash openssl

WORKDIR /evolution

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

COPY --from=builder /evolution/package.json ./
COPY --from=builder /evolution/package-lock.json ./
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
