# --- Etapa 1: compilar el frontend con Vite ---
FROM node:22-alpine AS build
WORKDIR /src

COPY package*.json ./
RUN npm ci --no-audit --no-fund

COPY . .
ARG APP_VERSION=local
ENV VITE_APP_VERSION=$APP_VERSION
RUN npm run build

# --- Etapa 2: servir los archivos estáticos con nginx ---
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
EXPOSE 80
