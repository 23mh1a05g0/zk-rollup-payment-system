FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 4000

# Set environment variables if needed
ENV PORT=4000

CMD ["node", "src/server.js"]
