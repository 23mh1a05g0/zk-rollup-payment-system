# Stage 1 - Build the web app
FROM ghcr.io/cirruslabs/flutter:3.22.0 AS build

WORKDIR /app

# Enable web support
RUN flutter config --enable-web

# Copy files and get dependencies
COPY pubspec.yaml ./
RUN flutter pub get

COPY . .

# Build web release
RUN flutter build web --dart-define=API_BASE_URL=http://localhost:4000 --release

# Stage 2 - Serve using Nginx
FROM nginx:alpine

# Copy built assets
COPY --from=build /app/build/web /usr/share/nginx/html

# Update Nginx config to listen on port 8080 instead of default 80
RUN sed -i 's/listen\( \)*80;/listen 8080;/g' /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
