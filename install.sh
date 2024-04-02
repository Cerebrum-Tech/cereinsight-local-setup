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

if [ -x "$(command -v docker)" ]; then
    echo "Docker is installed."
    echo "Docker version: $(docker --version)"
else
    echo "Docker installation failed."
    exit 1
fi


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

# Step 8: create .env file
cd /home/cerebrum/
cat <<EOF >.env
NODE_ENV=development
OPENAI_CHAT_MODEL=gpt-4
ANSWER_LANGUAGE=Turkish
NEXT_PUBLIC_CERE_API_DOMAIN=https://api.testserver.local
NEXT_PUBLIC_API_URL=https://api.testserver.local
NEXT_PUBLIC_COMPANY_DOMAIN=cerebrumtechnologies.com
BASE_URL=http://localhost:3000
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET='AceQrwqSgXHaDDia0jRJ5YY6TWN8NgjN0YrLEGdJORI='
BOT_ID=c8d96019-da62-42ec-ac95-72eba4c687b0

VIRTUAL_HOST=cereinsight.testserver.local
CERT_NAME=testserver.local

CONTAINER_NAME=cereinsightfe
  
NEXT_PUBLIC_BOT_OPENING_TITLE=CERE BOT 3
NEXT_PUBLIC_NEXTAUTH_SECRET=AceQrwqSgXHaDDia0jRJ5YY6TWN8NgjN0YrLEGdJORI=
NEXTAUTH_SECRET=AceQrwqSgXHaDDia0jRJ5YY6TWN8NgjN0YrLEGdJORI=
NEXT_PUBLIC_BASE_URL=http://localhost:3000
NEXT_PUBLIC_VIRTUAL_HOST=cereinsight.testserver.local
NEXT_PUBLIC_BASE_DOMAIN=cereinsight.testserver.local
FE_DOMAIN=https://cereinsight.testserver.local

  
DALLE_RESOURCE=swedencerebrum
DALLE_DEPLOYMENT_ID=dalle3
DALLE_KEY=d16faa5e3d1444be912ce9f435049f2a
DALLE_API_VERSION=2023-12-01-preview


API_DOMAIN=https://api.testserver.local
DOMAIN=testserver.local
OPENAI_API_KEY=ddddd
AZURE_OPENAI_KEY="d16faa5e3d1444be912ce9f435049f2a"
AZURE_OPENAI_API_VERSION="2023-12-01-preview"
AZURE_OPENAI_API_INSTANCE_NAME="swedencerebrum"
AZURE_OPENAI_DEPLOYMENT_NAME="sweden4"
REGION="swedencentral"
AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT_NAME="ada"
PROXY_NAME=webproxy
IMAGE=cerebrumtech/cereinsight:gk35

LLMA2_BASE_URL=https://llm.testserver.local
TRANSLATION_BASE_URL=https://mt.testserver.local
EMBEDDING_BASE_URL=https://embeddings.testserver.local
LLMA2_MODE=/root/models/Mixtral-8x7B-Instruct-v0.1-GPTQ
NEXT_PUBLIC_SUMMARIZE_API_DOMAIN=https://summarizer.testserver.local

DNS=10.0.0.1
NODE_TLS_REJECT_UNAUTHORIZED=0
EOF

# Step 9: create ceremeetapi .env file
mkdir ceremeetapi
cd ceremeetapi
cat <<EOF >.env
PORT=8000
NODE_ENV=development

DEPLOYMENT=pro

POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=ZQYJNRk33aeqd6wKmty8w
POSTGRES_DB=node_api

JWT_ACCESS_TOKEN_PRIVATE_KEY=LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlKS1FJQkFBS0NBZ0VBbDlvZkNvNHR1dmh3dkxCeXBJbkJiaE51c3B3dmcvNUJ4b0pRWjdxL2dWbkFLaDBqCnBhTVliUnp4RzVyQnN4NDE0VDR1U2w5SnM4TjFTRVR5bFVMNnk1SUZiT0ZMN0RSd0VMWjlFUWZQMXVGNXl1OEoKdURlR0NoNWYrTENtc1FQYXY1SHRaaElDWlNpRzN6RzhITTFmVFY4QThFSFNIamFIZ0duNHRnWXk1U0JpTzRqVApWNVh4aFpvSXF4MWMrR0hGWTlVMUhlNUN2ODZmakpoc1ZQOU9YNTRqUmxIRGZ1a3REQndMUjF5cVRkQ3k3WlN2CmRkYzBBTEtjRVV4VE4xY2ZHb2Y4ZWQwR0VrUU1YT0t0QU5tS3N2Q3hvR0RuVm5SVE4rYTVHK1NydSszYUxEOVAKaU5VdUR1b2NxYzBEby9BTE1EeHdTdXpveHNRMis0b29oUk9QZVRwaStPSUxNT3FlTjBFb3RpM2RQUGpHUjRINApvMzRNTEdXcVRnZ0U1OWZKQVlZbXJsbzFlVFFHY1F1RXBnWGlVTldZWTRxV0JTcVd3dVN0ZXh5VksvcWxrUnZLClpsWGZnckdCb1hjUjJqb1Boekh2U1FSZGZXRnRZcG9RMVRicFE1WlhjSGJ3Y2dYSXhXc1RwRHU3UnlVOG8veVIKS0o3Lzl2WUlFTjdDQkt4ODNpM2J0WUlTd29seVJ4WHBpdVBHeStIY2xHbUpqREtIUzhXZzhjQk93YlNIMkNHVApxZy94cERBZ3FyUGUvV0p4UzRjUWw1NFBUeVN4K0FXaCtxSEwvTVViR0ZNeGtvSnpFL3hiVkNNQkZTZnAzSFR0CmxJUzA3RHRSS2FYSjdtSk9GUXpGVG9FTWxrOFhYY0t4YVBYeVE1VFMvdlV3R3dVMFoyMU1US0E1ZGtjQ0F3RUEKQVFLQ0FnRUFnditua2JxUUZ1RG1tTkQ3UlppVlp2bWFvTGorZ0xiaVZYYnNHR0JSZnl4SEM4MnhoOTRJWDNEOQpTeHdaaUFWQzQvcDVncTFyYm9ucTdwcVVUMUhGKzhJUHJoczZIUjRyb3k5YSswc3E4S3Y1SHFsU1VEcU9Cc0tuCmRtb21rMFRJL0VUT2NTU09MbWhrMmIwVkZCL1QzSEpkNCtaVWRyNEI3VFQrVzBGRHZNaFFGaDMyZkhPZE5PMXEKRnZ3d3pSSERjRmxwQmxZWi9WQXA4ZWM0WmFjT0hJeld6MzRQMGJja3BuSzNCQ3didXgrVWpFS2RqMkpFdVdsYwpHOHdsYWZOZG9NeTVjUVBNamd0b1F1VkY3QnEvZlprSkUxc2xsejZvMyt2SnV4ZHRVNlZnZHBWemJvN0J1aG9hCitoMGp5OVIwUW51UlFBSGEya1pCVElTbWFnOHkwRUc2V3VWWVp4L1ZjNnVOVVg1T1VKUmhFSGpJckhCVnBBNW0KZlVJcFUrWEhycVBKMlBvdWJGelNZWkxKKzNsZ1FWenVWS3FBK3NSQWRYQm9EK2xFaFh4Y3pIcnA3Z1d2REFrSQpMdm1VSWNNZ2lmREZnR3k1VHUybTdoMGZQVTZSZlJKRWJObWt1aFRTeFJremZYZDV2aENvVVo0dTZPcUREcDd5CjNQSGdOVDJLcTFlMy9pc0FxalRaRWFjRlJQVFlIMmFlcjhQdXdVVlpOSjJQNWRsVlNpWDJtM3BPbGRRRGM4UDIKT1NERjU5aWQrRWZxVVh4eGFzanJicGdCdy8wdFZLWWhGS1pkSlVqNStWdmhKK3IvVS95b20wbFlQcnRPM0FwVgpjK0RqOU1JLytza1QzSkpzYmoxUGtqTmJldmJtZjJzNU5rRHFzaXYxVXVOczhkTjNvUUVDZ2dFQkFPSXQ4M1ljCmFQRXpJN1RnTVhkU3htM3RuOS84T3VqTEdLVGZYSG94cURtaUFINXY4bG5JZkY3RWxPV1BWek1IaVZmWCtEYUgKZyt2L09qd2V4YzRMQnV4cVJIN2FNQ215cllxRG1MSXFRVXNKR0paRWlQajR2dHBtcUprNkx3YllTeWo2ekVjbApWaGg0RGhNeTE4blBOZjdtbUJrTTQrR1MweFFKZjNQMWU0bFkrTHQ3b3pKa1BMZkljU2Vld1dQWGI0VWJhMkNKCitnNUtwZkFHZmkyTDRyNDFmcTBLVlZJRE5GVjl6SWp4UkxrWFhxNU1qWnVJQW52ak1jRXE2a29VWXRrdjRFclEKalM3T0toVmhEeDIzMXlodUxUSVVrazJrbGVOVFowLzhCUVZIZkRZM0RDd3B6cjBQRVRHaVN2bzVFSnRVNSsxcgorK3JMNUdGUzVkQU9rWUVDZ2dFQkFLdmZkUVV2dE1VYWhDc29WVWVDck9jSnhWTFhHeFRqcS9CenZGVllQWWpQCktjMSt1QzROZXZ5Y2dSM09LRlYrVHpqUmtaS1pYNFRUS1BmNHo4V0JyYkY3c0RHOWl5SWh0bzVqYmc2b0NVU1QKY1dlc3BZSmxOQUc5ano2OEdGRXI1bTN4bVVUMFpyZlphSFlDWkxhSXVxWSsvMlRJemRMUDdvQ0lCNkJsZEg3RwpJRlBHQXRiTmd1L1dPZHJCRHd5bjlSLzVoTWRpbDh2cnBGSzF1ZS8vTG96QzVtOWxtWkx3ODNNZDd5WFNJM0JMCmI1N2ovYzdYZkNONW1hN0VlOVo3VzExelozMGdJL3crVCtEUk01VWs4MFNPSXZGaHcySEhRMEMwdkNjanNqOWUKVmdsQXZKWWw1UzRsT2VsY2RvM085K1QyMXpuQVFqcDkwUjZzOTdydDI4Y0NnZ0VCQU1pYk52ZklKTy9oaXNidgpuaEFXVTdiR2J1bUwzbmdCUXI5ZytMWE1lMGQ2djNObE9RK1crWEJZYlRQYVdkNEJ6amdpYnAxMnZuUS9zRmdJCmR5clRydlZiSDV0ZlRCNS93dG82OCtENkIyVlZFUUNla3RvNFRaYUtQUG1DbUprNm1CY2xzcTlibHl3bXQxMGgKMkRDL1gwWFJJby85VmRVSms3dU8zUU50ZEgrU2NUSmdhNVBUUWVORG5kRWxScU9XUGV4U01IKzBnUnZSNjdHagpJS0NuRkpuZCtwZmh0V0VEUkpTYStpRnYxS05SN2dFc0Z1RWUxZzBwcWtTSkdycFBzSWl2cFFEV1RwSjMrdTF4Clk2WFpHN1ZaV3k2eS9qeHRRU0FhSm1UVHcyUTJUaDRMM3ZrQXI4UVJyQTlZd2FXRG5ZNFgxWWxJSUd6VklKK04KbGhWZUJvRUNnZ0VBUFRzYXdZSkJjSWNGMXlwRFYzcWlocHpnZzZiR3F5YUJOdVRFajlNaitQMTA4eFRXSVBJRQpnc0p1N1dObzB5eHdwTmxrZDBuVTBjazRxejhsSmtRUTBVNHpjMFVIc0YwNllIZmoyYXpid0dhVzNFeVJtbWJiCnBGTVlHVTJCakVtTGlsZXNOdmlyTDR4d3Zyb1RqMFFlMnVOT3NXVW9qcFl0YmZVSVlvaENmSGV4UktjaWs4d2IKZmI1Z1ZpSzViZFRZYTAvRmtoTDU2VmhGN29GM2dKejB4SWthOTB6RzdhYVIxTTB4U2RRWGRBWXIrZnRYakwwUQpLTU5Ga1JIRzNKNk42amtYQVdqVjZTTjU2YW9lS21CRG1vVFl4ZzRDUVc5djhqbHhYckJFN0haN1NFaWI1eElSCkYrT0RRalFDdUhxbnJoYVNqcXlENjdxdktiS05memNHT1FLQ0FRQmZ6eDNhbDBzRFhZU1ZzZSthbDNCU0V2YnAKVDBuYXNSWWo0aTRRTHY4MDBYSTkxY0E1WFZjbVQ4QXpjdlpjRDNhU2lIZHdiN0M2U3hmYmE2dGdrWjUzQmVvVQoza1Z6Yk9tWFhvL2lIRFd3SXQ2YmVFYTduWHVvU25Zd1FJN0FTSUQyOUZ2VmNnc09nK1JmUmN1S3JCQkxrM2l5CkdhWkxXTEdJbmd0YmJhOEpJdVhDOHJqMlhQamtiMVdLRUtBZkIyVDRZcVB0aThlZmxkd0NwS2dRMGlyYy9OMVIKZ0lROFFRc2F0aS92UUswMG9hUjdDT01sby9sTGNZRGxXR0ZHc0VxS01meDU1eFk2c2VkaEVNOGtsYkx1VVJzUAp5b3F0TDNYN0Q0dUx0c2NTQXZlU21YcDhBWWpTL2c5ZlcvcHFld05KdVRVTTFBOXFMWGpuVUkwZVJjZWQKLS0tLS1FTkQgUlNBIFBSSVZBVEUgS0VZLS0tLS0=
JWT_ACCESS_TOKEN_PUBLIC_KEY=LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQ0lqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FnOEFNSUlDQ2dLQ0FnRUFsOW9mQ280dHV2aHd2TEJ5cEluQgpiaE51c3B3dmcvNUJ4b0pRWjdxL2dWbkFLaDBqcGFNWWJSenhHNXJCc3g0MTRUNHVTbDlKczhOMVNFVHlsVUw2Cnk1SUZiT0ZMN0RSd0VMWjlFUWZQMXVGNXl1OEp1RGVHQ2g1ZitMQ21zUVBhdjVIdFpoSUNaU2lHM3pHOEhNMWYKVFY4QThFSFNIamFIZ0duNHRnWXk1U0JpTzRqVFY1WHhoWm9JcXgxYytHSEZZOVUxSGU1Q3Y4NmZqSmhzVlA5TwpYNTRqUmxIRGZ1a3REQndMUjF5cVRkQ3k3WlN2ZGRjMEFMS2NFVXhUTjFjZkdvZjhlZDBHRWtRTVhPS3RBTm1LCnN2Q3hvR0RuVm5SVE4rYTVHK1NydSszYUxEOVBpTlV1RHVvY3FjMERvL0FMTUR4d1N1em94c1EyKzRvb2hST1AKZVRwaStPSUxNT3FlTjBFb3RpM2RQUGpHUjRING8zNE1MR1dxVGdnRTU5ZkpBWVltcmxvMWVUUUdjUXVFcGdYaQpVTldZWTRxV0JTcVd3dVN0ZXh5VksvcWxrUnZLWmxYZmdyR0JvWGNSMmpvUGh6SHZTUVJkZldGdFlwb1ExVGJwClE1WlhjSGJ3Y2dYSXhXc1RwRHU3UnlVOG8veVJLSjcvOXZZSUVON0NCS3g4M2kzYnRZSVN3b2x5UnhYcGl1UEcKeStIY2xHbUpqREtIUzhXZzhjQk93YlNIMkNHVHFnL3hwREFncXJQZS9XSnhTNGNRbDU0UFR5U3grQVdoK3FITAovTVViR0ZNeGtvSnpFL3hiVkNNQkZTZnAzSFR0bElTMDdEdFJLYVhKN21KT0ZRekZUb0VNbGs4WFhjS3hhUFh5ClE1VFMvdlV3R3dVMFoyMU1US0E1ZGtjQ0F3RUFBUT09Ci0tLS0tRU5EIFBVQkxJQyBLRVktLS0tLQ==

JWT_REFRESH_TOKEN_PRIVATE_KEY=LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb1FJQkFBS0NBUUJ3eU1UeWpCeGVxdzh4MUFtZEh4aVE4VUg1MWxyME8xdTVaakFJS2hVdUVyeVZDRndNCjAvWFR5VUtLeTg1SzVEdkhlZ1ZEMGtzUGs5MWw2K0gvTU9VMFRIOU5Ic0NNZGR2dFUySUUyUmtGVUNJVnpvTzIKRFpuTEJLOVM3UUZaQjdDUHBWTFZnaER2aytPd20raXdvdm5xYVFJanczWFJadmNiSUppd0pBR250N3k0T0JjdwpTaXN3QXVINURvTVlhV3NqbnF5WGR2VUVadHhxU3YvWXgvZmxpQWxucHA2Ymd0QVNoeWM5U25DMnFlZ3pzS0V0CjhTcmNrL2VsZjhaeFhESHdmWEZyZUNHallGYkZsUmMwZXZzMmkwTUJqVThmZ3QrWHo2eFE5NDdaUEllZm5Lc1kKYVZvTVBCRktMdG9GMTA0MXZ0ZjVpdGQvVGZCaHJWRmNjcUx6QWdNQkFBRUNnZ0VBVzVYOXNNU3NhUWZaNytteQo0TitXa0dVSjRYcjdJeWRzcGRKZ29OQ2pvR1ZndEZrMGZzcEU3dldaVHFLUDQrc1F6RHkvTjhMMlp6RDQ4Y0lxCkpKT3RITm9kNmg5VjF2b0NYT2VBU2xXTlp1NGFyOENpM2x5UERmakE4c001ZS9XdG9BaHRpcW56WE1tb2RRczIKV3ZJTnBoZ2R2N01DNHNnTlUvOFZYcnZ1aUNXcEFLRFZPcnRJZHB4RlFFZmtsZS9LNVovK2xrSzEvTndBWWZrbwpITXU4TnQ5NW0xVFozUDdVRFNZSFAySjRjcXBJZmtDNks4ellxRWhpaGRDcEZaRVZ1THJET0dTaTFMVGdFOHJnCk91NHF5QlVaTGdETm5rL3djalNvSDJtVmhMSEtBWFJtMHI2TkNqY0pPMWliZHFmTnhGcHNDMmVqVm14WUdsU0wKbzE5dHFRS0JnUURMR1hlWm9leVFrbFBCQlVyTnBpUDluMnY4c2MyOXVnV3lXNGpSeFdXZGpubFRXZjFyN005MgpQQmFJSTFRbDR3ZjREbGlKWVlQVklzbUt0ZkgvV1hGM0RzaEYwSDlaOGJHelpGb0Q1UEVaRXRpcXRCUzF4R1B6Clg2bHV0Y1RDMnBuSjl0OHhGTUNwbHQ2c3pzNHo3YUI5NllnKzVtbURVSXJxb1Ira1JGZkdCd0tCZ1FDT0tTVTQKRlRjb3RWR0ZUV0o4K3B1cHZvcjBqdXVHWWo1WjFEZ2ZwUjk1bmx5Nkw3VEVEandnaXNtckIyeXJpWkNPd2k3cgpZZVNkTFhDbXovNFRMbzJ0alozRjhZZDhpN1RJTWRsek5jTld6L2NSaHR6dDlzWm1WQktmWTlMU1pCdVdRdko1CnJVZERJL010dlI3dm9PbUxLSWpHZ1EvUTA4SE5qTStDbnBkZ3RRS0JnRHNSS1F0eFlFK2JmdWhBRmNWQmNHNHUKazBWbW9LTnhHbjhJeC8zYUh2ZDNuQ2wxbnBKb3lOMW1GRmQ3anRtRjhhZGU1TGp2dDF1aFJtUWxEa0JwVHVxRgpUaEdmMWFuZTlRTnJTQktoM3N5Z0FvdUMzQk1SRHRDVkhiMm85NVNENXY0cDRqZHdCYWhNekc0TnAwTEs5VVlwClNRcWlFRVcwZ3ZKQjhlWGdTbmE1QW9HQVZZV0hNSUFDMk9pTGpFZ0xrZWdwc1NwQjZmSDQyclZMa1RyTU1LMWoKakFTckFBOG5Eak1LRlFHcFpNeG9vYUYyWjR1R01uQ0gyYzYyVUlRYjgybzBMVTVldGZBaGM5bVAva2VPNjNKUwplMjFNMHl4d3lHK0cxNVNJUjM4RUd6SENMdGxEaWRPbVpVdkJSYWphYllvK05VdERUVGZqVGR1MllYUHVla1B5CkNXa0NnWUFZNXRhTkd3cFIxeWFsZHlaK2thQkNTK0Z3YWEyaXQyc1ZuemI3QzB1NUdyS3htWnhyeXgwUVI1SksKVk1SRjJBdnl0RG1OSE9va0xvVkpmZVFIMW5TcWN6ekJxWjZYTjUrTHJNSUxZUmo2RDVOY3N5RFV6N2NPcTNpZQpyNEhrOUhTNVBQbEd1TzJSTUZENExnSmFDVUdxOUY5UnVzNGJTRWVGZ1laNWtlc0hwQT09Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0t
JWT_REFRESH_TOKEN_PUBLIC_KEY=LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklUQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FRNEFNSUlCQ1FLQ0FRQnd5TVR5akJ4ZXF3OHgxQW1kSHhpUQo4VUg1MWxyME8xdTVaakFJS2hVdUVyeVZDRndNMC9YVHlVS0t5ODVLNUR2SGVnVkQwa3NQazkxbDYrSC9NT1UwClRIOU5Ic0NNZGR2dFUySUUyUmtGVUNJVnpvTzJEWm5MQks5UzdRRlpCN0NQcFZMVmdoRHZrK093bStpd292bnEKYVFJanczWFJadmNiSUppd0pBR250N3k0T0Jjd1Npc3dBdUg1RG9NWWFXc2pucXlYZHZVRVp0eHFTdi9ZeC9mbAppQWxucHA2Ymd0QVNoeWM5U25DMnFlZ3pzS0V0OFNyY2svZWxmOFp4WERId2ZYRnJlQ0dqWUZiRmxSYzBldnMyCmkwTUJqVThmZ3QrWHo2eFE5NDdaUEllZm5Lc1lhVm9NUEJGS0x0b0YxMDQxdnRmNWl0ZC9UZkJoclZGY2NxTHoKQWdNQkFBRT0KLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0t

IYZIPAY_URI=https://api.iyzipay.com
IYZIPAY_API_KEY=zudddd
IYZIPAY_SECRET_KEY=Eddd

IYZIPAY_SANDBOX_URI=https://sandbox-api.iyzipay.com
IYZIPAY_SANDBOX_API_KEY=sandbox-NqGoKIwddd
IYZIPAY_SANDBOX_SECRET_KEY=sandbox-wcMbjddd

EMAIL_USER=no-reply@----.com
EMAIL_PASS=----
EMAIL_HOST=smtp.----.com
EMAIL_PORT=465
EMAIL_SECURE=true


REDIS_URL=redis://redis:6379
# REDIS_URL=redis://redis:6389
REDISdev_URL=redis://redis:6379
REDIS_PASSWORD=EPn2YCUkQ7csv

POSTGRESdev_HOST=postgres
POSTGRESdev_PORT=5432
POSTGRESdev_DB=node_api


DOMAIN=api.testserver.local
PROXY=webproxy
EMAIL=alp@cerebrumtechnologies.com

ORIGIN=https://testserver.local
HOST=https://api.testserver.local
COOKIEDOMAIN=.testserver.local

DEV_HOST=https://unknownland.org:8001

FILESERVERDOMAIN=files.testserver.local

FRONTENDDOMAIN=testserver.local


GOOGLE_PLAY_API_EMAIL="ce------nt.com"
GOOGLE_PLAY_API_KEY="-----BEGIN PRIVAT---ND PRIVATE KEY-----"
GOOGLE_PLAY_PACKAGE_NAME=com.CerebrumTech.CereAi
GOOGLE_PLAY_PRODUCT_ID=cere_premium


STABLE_DIFFUSION_API_KEY=hXTv-----T


OPENAI_FREE_LIMIT=4
OPENAI_PREMIUM_LIMIT=3000
OPENAI_KEY=sk----8A4
OPENAI_API_KEY=sk-5h----DJP38A4

GOOGLE_API_KEY=AIzaS---yxUVc
URL_Shorten_API_KEY=bdb----f06b7

CONVERSATION_TEMPERATURE=1
CONVERSATION_QUESTION_LIMIT=10
CONVERSATION_MAX_TOKENS=2500
CONVERSATION_START_TOKENS=150
CONVERSATION_MODEL=text-davinci-003

INVOICE_EMAIL=ku---s.com

OPENWEATHER_API_KEY=322----ad1f1f
URL_SHORTEN_API_KEY=bdb2c----6b7

GOOGLE_CLIENT_ID=331611527----leusercontent.com
GOOGLE_CLIENT_SECRET=GOCS-----6DrNUPqug

TWITTER_CONSUMER_KEY=eBjBlOX---8kjE42yPM
TWITTER_CONSUMER_SECRET=ZnT6OvA2S---Pfamk6GAJ2MIIlYDKCb

NESTLE_MS_TENANT_ID=12a---d479f4a
NESTLE_MS_CLIENT_ID=8633bac5---12f833a55
NESTLE_MS_CLIENT_SECRET=788a---2167a
NESTLE_MS_REDIRECT_URI=https://ww----estle
NESTLE_MS_CLIENT_SECRET_VALUE=j2d------cOv

DALLE_RESOURCE=swe-brum
DALLE_DEPLOYMENT_ID=da--3
DALLE_KEY=d16---49f2a
DALLE_API_VERSION=20---ew

AZURE_OPENAI_RESOURCE=co---mn
AZURE_OPENAI_DEPLOYMENT=g---4
AZURE_OPENAI_KEY=d27---bed2
AZURE_OPENAI_API_VERSION=20---ew

DEFAULT_DOCBOT_IMAGE=do---7
NESTLE_DOCBOT_IMAGE=do---3

NODE_TLS_REJECT_UNAUTHORIZED="0"

VIRTUAL_HOST=api.testserver.local
CERT_NAME=testserver.local
NODE_TLS_REJECT_UNAUTHORIZED=0

EOF

# Step 10: create ml-containers docker-compose.yml file
cd /home/cerebrum/
mkdir ml-containers
cd ml-containers
cat <<EOF >docker-compose.yml
version: '3.9'
services:
  mt:
    image: cerebrumtech/mt:mar27
    restart: on-failure
    runtime: nvidia
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl --location 'http://localhost:8000/api/v1/translate' --header 'Content-Type: application/json' --data '{\"src\":\"en\", \"tgt\":\"tr\", \"text\":\"hi\"}' || exit 1"
        ]
      interval: 120s
      timeout: 20s
      retries: 2
      start_period: 90s
    ports:
      - 8009:8000
    volumes:
      - ./mt/models:/app/models
      - ./mt/config.json:/app/config.json
    environment:
      - MT_API_CONFIG=/app/config.json
      - MT_API_DEVICE=gpu #or gpu, if so make runtime:nvidia
      - MT_API_THREADS=6
      - MODELS_ROOT=/app/models
      - NVIDIA_VISIBLE_DEVICES=2
      - NVIDIA_DRIVER_CAPABILITIES=all
      - VIRTUAL_HOST=mt.${DOMAIN}
      - CERT_NAME=${DOMAIN}
      - max_length=4000
      - CUDA_LAUNCH_BLOCKING=1
    dns: 0.0.0.0

  text-embeddings-inference:
    image: ghcr.io/huggingface/text-embeddings-inference:1.1
    command: --model-id intfloat/multilingual-e5-large-instruct
    runtime: nvidia
    restart: unless-stopped
    environment:
      - VIRTUAL_HOST=embeddings.${DOMAIN}
      - CERT_NAME=${DOMAIN}
      - NVIDIA_VISIBLE_DEVICES=2
    volumes:
      - ./embedding/data:/data
    ports:
      - "8090:80"

  llmapi:
    image: cerebrumtech/vllm:mar27
    container_name: llmapi
    restart: on-failure
    shm_size: 15.91gb
    command: --model /root/models/Mixtral-8x7B-Instruct-v0.1-GPTQ --gpu-memory-utilization 0.9 --swap-space 1 --tensor-parallel-size 2 --max-model-len 8000  --dtype half
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl --location 'http://localhost:8000/v1/chat/completions' --header 'Content-Type: application/json' --data '{\"model\": \"/root/models/Mixtral-8x7B-Instruct-v0.1-GPTQ\", \"messages\": [{\"role\": \"user\", \"content\": \"say just hi\"}], \"temperature\": 0, \"top_p\": 1, \"max_tokens\": 50, \"presence_penalty\": 0.3, \"stream\": false, \"safe_prompt\": false, \"frequency_penalty\": 0.6, \"random_seed\": null}' || exit 1"
        ]
      interval: 150s
      timeout: 20s
      retries: 2
      start_period: 90s
    environment:
      - VIRTUAL_HOST=llm.${DOMAIN}
      - CERT_NAME=${DOMAIN}
      - HUGGING_FACE_HUB_TOKEN="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"
      # - TRANSFORMERS_OFFLINE=1
      # - HF_HUB_OFFLINE=1
    volumes:
      - ./llm/cache/huggingface:/root/.cache/huggingface
      - ./llm/models:/root/models
    ports:
      - "8008:8000"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [ gpu ]

  summarizer:
    image: cerebrumtech/summarizer:latest
    runtime: nvidia
    restart: unless-stopped
    environment:
      - VIRTUAL_HOST=summarizer.${DOMAIN}
      - CERT_NAME=${DOMAIN}
      - NVIDIA_VISIBLE_DEVICES=2
    volumes:
      - ./llm/summarizer/cache:/root
    ports:
      - "8010:8080"
    dns: 0.0.0.0
networks:
  default:
    name: webproxy
    external: true
  backend:
EOF

# Step 11: create ml-containers .env file
cat <<EOF >.env
DOMAIN=testserver.local
EMBEDDING_MODEL=BAAI/bge-large-en-v1.5
EMBEDDING_REVISIONS=refs/pr/5
EOF


# Step 12: Run Docker Compose
cd /home/cerebrum/cereinsight
echo "Starting Docker containers..."
sudo docker-compose up -d

echo "Containers have been started successfully."
