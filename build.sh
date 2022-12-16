#!/bin/sh

TRILINOS_VERSION="trilinos-release-12-12-1"
XYCE_VERSION="Release-7.6.0"
CONTAINER_NAME="vlsir-test-container"

docker build . -t $CONTAINER_NAME \
    --build-arg TRILINOS_VERSION=$TRILINOS_VERSION \
    --build-arg XYCE_VERSION=$XYCE_VERSION
