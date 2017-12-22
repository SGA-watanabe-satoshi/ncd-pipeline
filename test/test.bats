#!/usr/bin/env bats

@test "Run arbitrary commands with the container" {
  if docker inspect echotest > /dev/null 2>&1; then
    docker rm echotest
  fi
  output=$(docker run --name echotest ${DOCKER_REPO}cd-pipeline echo 'Drake' 2> /dev/null)
  [ "$output" == "Drake" ]
  docker rm echotest || true
}