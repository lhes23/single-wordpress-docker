# Ubuntu preparation for wordpress docker

## Dowload both files and make it executable

```
curl -L -o install_docker.sh https://raw.githubusercontent.com/lhes23/single-wordpress-docker/refs/heads/main/install_docker.sh && sudo chmod +x install_docker.sh
```

```
curl -L -o setup_wordpress.sh https://raw.githubusercontent.com/lhes23/single-wordpress-docker/refs/heads/main/setup_wordpress.sh && sudo chmod +x setup_wordpress.sh
```

## Option if not using local db

```
curl -L -o setup_wp_no_db.sh https://raw.githubusercontent.com/lhes23/single-wordpress-docker/refs/heads/main/setup_wp_no_db.sh && sudo chmod +x setup_wp_no_db.sh
```

```
curl -L -o .env https://raw.githubusercontent.com/lhes23/single-wordpress-docker/refs/heads/main/env.example
```

## Run the installation

```
./install_docker.sh
```

## Before running the setup wordpress, logout and login to take effect

```
logout
```

## Run the wordpress setup with the domain as an argument

```
./setup_wordpress.sh <domain>
```

## When DNS is pointing to the server, request the SSL certificate with certbot

```
docker exec wp_certbot certbot certonly --webroot --webroot-path=/var/www/certbot --email admin@<domain> --agree-tos --no-eff-email -d <domain> -d www.<domain>
```
make sure to change the <domain> name.

you can check the file request_ssl.txt
