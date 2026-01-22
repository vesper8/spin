#!/usr/bin/env bash
action_build() {
  # Build the containers with `docker-compose`
  echo "action_build: $COMPOSE_CMD build \"$@\""
  $COMPOSE_CMD build "$@"
}