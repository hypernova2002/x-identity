# syntax=docker/dockerfile:1

FROM docker.io/library/node:24-slim AS base
WORKDIR /app


# Local development image, used by docker compose. The app source is bind-mounted at runtime.
FROM base AS development

COPY package.json package-lock.json ./
RUN npm ci

EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]


FROM base AS build

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
ARG VITE_API_BASE_URL
RUN npm run build


FROM docker.io/nginxinc/nginx-unprivileged:1.29-alpine AS production

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
