# syntax=docker/dockerfile:1
#
# Targets:
#   dev         - Vite dev server with hot reload (source bind-mounted)
#   production  - static build served by unprivileged Nginx on port 8080

FROM node:22-alpine AS deps
WORKDIR /app
RUN chown node:node /app
USER node
COPY --chown=node:node package.json package-lock.json ./
RUN npm ci

FROM deps AS dev
COPY --chown=node:node . .
EXPOSE 5173
CMD ["npm", "run", "dev"]

FROM deps AS build
COPY --chown=node:node . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine AS production
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
