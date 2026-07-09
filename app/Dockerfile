# ==========================================
# STAGE 1: Build (Biên dịch code React)
# ==========================================
FROM node:16 AS builder
WORKDIR /app

# Copy và cài đặt dependencies
COPY package*.json ./
RUN npm install

# Copy source code và tiến hành build
COPY . .
RUN npm run build

# ==========================================
# STAGE 2: Deploy (Phục vụ file tĩnh bằng Nginx)
# ==========================================
FROM nginxinc/nginx-unprivileged:alpine

# Copy toàn bộ file tĩnh đã được build ở Stage 1 sang thư mục của Nginx
COPY --from=builder /app/build /usr/share/nginx/html
# Expose cổng 80 (cổng mặc định của web tĩnh)
EXPOSE 8080

# Chạy Nginx ở chế độ background
CMD ["nginx", "-g", "daemon off;"]