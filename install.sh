#!/bin/bash

# Step 1: Update the System
echo "Updating the system..."
sudo apt-get update
sudo apt-get upgrade -y

# Step 2: Check if Docker is already installed
if [ -x "$(command -v docker)" ]; then
    echo "Docker is already installed."
    echo "Docker version: $(docker --version)"
else
    echo "Installing Docker..."

    # Set up the Docker repository
    sudo apt-get install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker’s official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Set up the stable repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y

    echo "Docker has been installed successfully."
fi
# Check if the docker group already exists
if getent group docker > /dev/null 2>&1; then
    echo "Group 'docker' already exists."
else
    sudo groupadd docker
    echo "Group 'docker' has been created."
    sudo usermod -aG docker $USER
    newgrp docker
fi

# Add the current user to the docker group


# Test Docker installation

# Step 3: Pull required Docker images
echo "Pulling required Docker images..."

# Pull cerebrumtech/cereinsight:latest image
echo "Pulling cerebrumtech/cereinsight:latest..."
sudo docker pull cerebrumtech/cereinsight:latest


# Pull nginxproxy/nginx-proxy image
echo "Pulling nginxproxy/nginx-proxy..."
sudo docker pull nginxproxy/nginx-proxy

# Pull nginxproxy/nginx-proxy image
echo "Pulling nginxproxy/nginx-proxy..."
sudo docker pull nginxproxy/acme-companion

# Pull cerebrumtech/faiss-python image
echo "Pulling cerebrumtech/faiss-python."
sudo docker pull cerebrumtech/faiss-python

echo "Docker images have been pulled successfully."

# Step 4: Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
echo "Docker Compose has been installed successfully."


# Step 5: Check and create the external network if needed
echo "Checking for the external network 'webproxy'..."
if ! sudo docker network ls | grep -q webproxy; then
    echo "External network 'webproxy' not found. Creating it..."
    sudo docker network create webproxy
else
    echo "External network 'webproxy' already exists."
fi

# Step 6: crete folders and files
sudo mkdir cereinsight
sudo chown -R $USER cereinsight
cd cereinsight
mkdir certs
mkdir conf


sudo mkdir /blob
sudo mkdir /blob/docbotVolumes
sudo chown -R $USER /blob/docbotVolumes
sudo chmod -R 777 /blob/docbotVolumes

# add nginx conf
cat <<EOF >conf/uploadsize.conf
client_max_body_size 256m;
EOF

cat <<EOF >conf/timeout.conf
proxy_read_timeout 600;
proxy_connect_timeout 600;
proxy_send_timeout 600;
EOF


# Step 7: Run docker-compose

cat <<EOF >docker-compose.yml
version: '2.2'

services:
  nginx-proxy:
    image: nginxproxy/nginx-proxy
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /home/cerebrum/cereinsight/conf:/etc/nginx/conf.d
      - vhost:/etc/nginx/vhost.d
      - html:/usr/share/nginx/html
      - /home/cerebrum/cereinsight/certs:/etc/nginx/certs:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
    restart: always

  acme-companion:
    image: nginxproxy/acme-companion
    container_name: nginx-proxy-acme
    environment:
      - DEFAULT_EMAIL=alp@cerebrumtechnologies.com
    volumes_from:
      - nginx-proxy
    volumes:
      - /home/cerebrum/cereinsight/certs:/etc/nginx/certs:rw
      - acme:/etc/acme.sh
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: always

  cereinsight-fe:
    image: cerebrumtech/cereinsight-fe:latest
    container_name: cereinsight-fe
    restart: always
    env_file:
      - /home/cerebrum/.env
    ports:
      - 3000:3000
    volumes:
      - /home/cerebrum/cereinsight/fe/log:/app/build/log
      - /var/run/docker.sock:/var/run/docker.sock
      - /blob/docbotVolumes:/blob/docbotVolumes
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
    links:
      - apibackend
    dns: 10.0.0.1

  apibackend:
    #   image: casusbelli555/apiback:latest
    container_name: apibackend
    image: cerebrumtech/ceremeetapi:latest
    restart: always
    ports:
      - "8000:8000"
    depends_on:
      - postgres
      - redis
    env_file:
      - ../ceremeetapi/.env
    volumes:
      - ./public:/app/public

  postgres:
    restart: always
    image: postgres:14
    container_name: postgres
    ports:
      - "5432:5432"
    volumes:
      - ./postgresDB:/var/lib/postgresql/data
    env_file:
      - ../ceremeetapi/.env
  redis:
    container_name: redis
    restart: always
    image: redis:alpine
    ports:
      - "6379:6379"
    volumes:
      - ./redisDB:/data
volumes:
  conf:
  vhost:
  html:
  certs:
  acme:


networks:
  default:
    name: webproxy
    external: true
EOF

# Step 5: Run Docker Compose
echo "Starting Docker containers..."
sudo docker-compose up -d

echo "Containers have been started successfully."
