#!/usr/bin/env bash
action_build() {
  # Build the containers with `docker-compose`
  echo "xxx - build.sh"
  echo "$COMPOSE_CMD build \"$@\""
  $COMPOSE_CMD build "$@"
}