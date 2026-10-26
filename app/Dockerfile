# Local testing only (Docker Desktop). AWS runs the app directly on EC2 via systemd.
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
