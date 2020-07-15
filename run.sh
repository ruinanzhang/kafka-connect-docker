#!/bin/bash
echo "Create new confluent vm container..."
docker-machine create --driver virtualbox --virtualbox-memory 6

echo "Config terminal window to attach it to new docker machine..."
eval $(docker-machine env confluent)

echo