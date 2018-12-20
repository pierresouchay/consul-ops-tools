#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "USAGE: $0 AGENT_URL"
  echo "       Example: $0 localhost:8500"
  exit 1
fi

agent_url="$1"

get_dcs() {
    curl -sS "$agent_url/v1/catalog/datacenters" | jq -r '.[]'
}

get_servers() {
    local dc="$1"
    curl -sS "$agent_url/v1/health/service/consul?dc=$dc" | jq -r '.[].Node.Node'
}

for dc in $(get_dcs); do
    echo "$dc :"
    for server in $(get_servers $dc); do
        echo -n "$server : "
        ssh -o StrictHostKeyChecking=no $server "consul version | head -1"
    done
done