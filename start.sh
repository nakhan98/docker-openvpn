#!/usr/bin/env sh

alias docker="sudo docker"
DOCKER_IMG="docker_openvpn"
DOCKER_CONTAINER="docker-openvpn"
OVPN_DATA="docker-openvpn-data"
CLIENT_NAME="client_1"
OVPN_FILE="~/$CLIENT_NAME.ovpn"
HOST="yourhost.com"
MAX_LOG_SIZE="8m"

echo "Stopping and deleting any  running container..."
docker stop $DOCKER_CONTAINER
docker rm   $DOCKER_CONTAINER

echo "Attempting to delete any existing volume"
docker volume rm $OVPN_DATA

set -e

echo "Re-building image..."
sudo docker build -t $DOCKER_IMG .

echo "Creating new volume..."
docker volume create --name $OVPN_DATA

echo "Generating openvpn config..."
docker run -v $OVPN_DATA:/etc/openvpn --rm $DOCKER_IMG ovpn_genconfig -u \
    udp://$HOST

echo "Generating CA..."
docker run -v $OVPN_DATA:/etc/openvpn --rm -it $DOCKER_IMG ovpn_initpki

echo "Starting Docker container..."
docker run -v $OVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --name \
    $DOCKER_CONTAINER --cap-add=NET_ADMIN --log-opt max-size=$MAX_LOG_SIZE \
    $DOCKER_IMG

echo "Generating client cert..."
docker run -v $OVPN_DATA:/etc/openvpn --rm -it $DOCKER_IMG easyrsa \
    build-client-full $CLIENT_NAME

echo "Saving client cert..."
docker run -v $OVPN_DATA:/etc/openvpn --rm $DOCKER_IMG ovpn_getclient \
    $CLIENT_NAME > $OVPN_FILE

# https://serverfault.com/a/822040
echo "Inserting Adguard DNS into ovpn file..."
echo "script-security 2" >> $OVPN_FILE
echo "dhcp-option DNS 176.103.130.130" >> $OVPN_FILE
echo "dhcp-option DNS 176.103.130.131" >> $OVPN_FILE
echo "dhcp-option DOMAIN $HOST" >> $OVPN_FILE
