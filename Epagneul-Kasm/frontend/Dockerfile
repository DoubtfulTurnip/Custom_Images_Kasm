# Epagneul Frontend Image
FROM node:18

WORKDIR /app
COPY . /app

RUN npm ci || npm install

CMD ["npm", "run", "serve", "--", "--host", "0.0.0.0"]
