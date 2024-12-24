#!/bin/bash

# Check if domain argument is provided
if [ -z "$1" ]; then
  echo "Error: No domain provided. Usage: ./setup_wordpress.sh yourdomain.com"
  exit 1
fi

# Assign domain from the argument
DOMAIN=$1

# DB_NAME="${DOMAIN//./_}_wp"
# DB_USER="${DOMAIN//./_}_wp"
# DB_PASSWORD=$(openssl rand -base64 12)
# DB_ROOT_PASSWORD="root"  # Use the same root password as in your docker-compose.yml

DB_HOST=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""


# Create the necessary directories
mkdir -p $DOMAIN && cd $DOMAIN
mkdir -p ./nginx/conf.d ./wordpress

# Generate docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  nginx:
    image: "nginx"
    container_name: wp_nginx
    restart: unless-stopped
    depends_on:
      - wp
    ports:
      - "80:80"   # HTTP
      - "443:443" # HTTPS
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
      - ./wordpress:/var/www/html
    networks:
      - wp_network

  wp:
    image: wordpress:latest
    container_name: wp
    volumes:
      - ./wordpress:/var/www/html
      - ./nginx/php.ini:/usr/local/etc/php/conf.d/uploads.ini
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: ${DB_HOST}:3306
      WORDPRESS_DB_NAME: ${DB_NAME}
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
    networks:
      - wp_network

  phpmyadmin:
    image: phpmyadmin
    container_name: wp_pma
    restart: unless-stopped
    ports:
      - "9005:80"
    environment:
      PMA_HOST: ${DB_HOST}
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD}
      UPLOAD_LIMIT: 300M
    networks:
      - wp_network

networks:
  wp_network:
    driver: bridge
EOF

# Generate php.ini files
cat <<EOF > ./nginx/php.ini
upload_max_filesize = 300M
post_max_size = 300M
EOF

# Generate nginx configuration for the domain
cat <<EOF > ./nginx/conf.d/default.conf
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://wp:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Output message for the user
echo "Docker Compose and Nginx config files created for $DOMAIN."
echo "Please enter database credentials"
echo "Run 'docker-compose up -d' to start the WordPress stack."

# Start the Docker containers
# docker-compose up -d