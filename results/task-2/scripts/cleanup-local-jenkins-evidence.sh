#!/usr/bin/env bash
set -euo pipefail

for container in task2-evidence-jenkins task2-evidence-registry; do
  if docker ps --format '{{.Names}}' | grep -qx "${container}"; then
    docker stop "${container}" >/dev/null
  fi
done

printf 'Task 2 evidence containers stopped and removed by Docker --rm.\n'
printf 'Existing Jenkins containers, volumes and images were not modified.\n'
