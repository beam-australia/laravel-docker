#!/bin/bash

set -e

docker login -e=$DOCKER_EMAIL -u=$DOCKER_USERNAME -p=$DOCKER_PASSWORD

docker tag beamaustralia/php beamaustralia/php:$TRAVIS_TAG

docker push beamaustralia/php:$TRAVIS_TAG
