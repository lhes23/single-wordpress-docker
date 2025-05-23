#!/bin/bash

# Check if domain argument is provided
if [ -z "$1" ]; then
  echo "Error: No domain provided. Usage: ./setup_wp_no_db.sh yourdomain.com"
  exit 1
fi

# Assign domain from the argument
DOMAIN=$1

# Check if .env file exists
if [ ! -f .env ]; then
  echo "Error: .env file not found. Please create a .env file with DB_HOST, DB_NAME, DB_USER, and DB_PASSWORD."
  exit 1
fi

# Load database credentials from .env file
set -o allexport
source .env
set +o allexport

# Create the necessary directories
mkdir -p $DOMAIN && cd $DOMAIN
mkdir -p ./nginx/conf.d ./wordpress

# Generate docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  wp:
    image: wordpress:latest
    container_name: wp
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
    ports:
      - "80:80"
    volumes:
      - ./wordpress:/var/www/html
      - ./nginx/php.ini:/usr/local/etc/php/conf.d/uploads.ini
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: $DB_HOST
      WORDPRESS_DB_NAME: $DB_NAME
      WORDPRESS_DB_USER: $DB_USER
      WORDPRESS_DB_PASSWORD: $DB_PASSWORD

  phpmyadmin:
    image: phpmyadmin
    container_name: wp_pma
    restart: unless-stopped
    ports:
      - "9005:80"
    environment:
      PMA_HOST: $DB_HOST
      MYSQL_ROOT_PASSWORD: $DB_PASSWORD
      UPLOAD_LIMIT: 300M
EOF

# Generate php.ini files
cat <<EOF > ./nginx/php.ini
upload_max_filesize = 300M
post_max_size = 300M
EOF

# Generate Nginx configuration for the domain and write to /etc/nginx/conf.d
if [ ! -d /etc/nginx/conf.d ]; then
  echo "Error: /etc/nginx/conf.d directory does not exist. Ensure Nginx is installed and the directory is present."
  exit 1
fi

export DOMAIN=$DOMAIN

sudo bash -c 'cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN localhost;

    root /var/www/html;  # Ensure the root points to the correct directory
    index index.php index.html index.htm;

    location / {
        proxy_pass http://localhost:80;  # Pointing to the WP container
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;  # Adjust PHP version as needed
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF'

# Test Nginx configuration and reload
sudo nginx -t  # Test for errors
sudo systemctl reload nginx  # Reload Nginx to apply the new config

# Output message for the user
echo "Docker Compose and Nginx config files created for $DOMAIN."
echo "Run 'docker-compose up -d' to start the WordPress stack."
