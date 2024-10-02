#!/bin/bash

# Check if domain argument is provided
if [ -z "$1" ]; then
  echo "Error: No domain provided. Usage: ./create_wordpress_stack.sh yourdomain.com"
  exit 1
fi

# Assign domain from the argument
DOMAIN=$1

DB_NAME="${DOMAIN//./_}_wp"
DB_USER="${DOMAIN//./_}_wp"
DB_PASSWORD=$(openssl rand -base64 12)
DB_ROOT_PASSWORD="root"  # Use the same root password as in your docker-compose.yml


# Create the necessary directories
mkdir -p ./nginx/conf.d ./certbot/conf ./certbot/www ./wordpress

# Generate docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  nginx:
    image: "nginx"
    container_name: nginx
    restart: unless-stopped
    depends_on:
      - wordpress
    ports:
      - "80:80"   # HTTP
      - "443:443" # HTTPS
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
      - ./wordpress:/var/www/html
    networks:
      - wp_net

  database:
    image: mariadb
    container_name: db
    command: "--default-authentication-plugin=mysql_native_password"
    volumes:
      - dbdata:/var/lib/mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root
    networks:
      - wp_net

  wordpress:
    image: wordpress:latest
    container_name: wp
    depends_on:
      - database
    volumes:
      - ./wordpress:/var/www/html
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: wp_db:3306
      WORDPRESS_DB_NAME: ${DB_NAME}
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
    networks:
      - wp_net

  phpmyadmin:
    image: phpmyadmin
    container_name: pma
    depends_on:
      - database
    restart: unless-stopped
    ports:
      - "9005:80"
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: root
      UPLOAD_LIMIT: 300M
    networks:
      - wp_net

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"
    networks:
      - wp_net

volumes:
  dbdata:

networks:
  wp_net:
    driver: bridge
EOF

# Generate nginx configuration for the domain
cat <<EOF > ./nginx/conf.d/default.conf
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    location / {
        proxy_pass http://wp:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Output message for the user
echo "Docker Compose and Nginx config files created for $DOMAIN."
echo "Running 'docker-compose up -d' to start the WordPress stack."

# Start the Docker containers
docker-compose up -d

# Wait for MariaDB to initialize properly
until docker exec wp_db mariadb -u root -p$DB_ROOT_PASSWORD -e "SELECT 1" >/dev/null 2>&1; do
    echo "Waiting for MariaDB to start..."
    sleep 5
done


echo "Creating database and user for WordPress..."

# Create the database and user
docker exec wp_db mariadb -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
docker exec wp_db mariadb -u root -p$DB_ROOT_PASSWORD -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';"
docker exec wp_db mariadb -u root -p$DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';"
docker exec wp_db mariadb -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

echo "Database and user for WordPress has been created."


echo "Manually request the SSL certificate with Certbot when dns is pointing to the server:"
echo "docker-compose run certbot certonly --webroot --webroot-path=/var/www/certbot --email your-email@example.com --agree-tos --no-eff-email -d $DOMAIN -d www.$DOMAIN"