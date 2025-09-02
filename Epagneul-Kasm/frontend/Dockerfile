FROM node:18

WORKDIR /app

COPY . /app

# Install dependencies
RUN npm ci || npm install

CMD ["npm", "run", "serve", "--", "--host", "0.0.0.0"]
