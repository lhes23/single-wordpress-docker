# Ubuntu preparation for wordpress docker

## Dowload both files

```
curl -L -o install_docker.sh https://raw.githubusercontent.com/lhes23/single-wordpress-docker/refs/heads/main/install_docker.sh &&

curl -L -o setup_wordpress.sh https://raw.githubusercontent.com/lhes23/single-wordpress-docker/refs/heads/main/setup_wordpress.sh

```

## Make both executable

```
sudo chmod +x install_docker.sh && sudo chmod +x setup_wordpress.sh
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
./setup_wordpress <domain>
```

## Run docker-compose up
cd into the domain directory and run docker-compose up -d

```
cd <domain>

docker-compose up --build -d
```
