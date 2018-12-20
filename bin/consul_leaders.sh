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

get_leader() {
    local server_addr="$1"
    ssh "$server_addr" 'consul info | grep leader_addr | awk -F" = " "{print \$2}" | cut -d: -f1'
}

for dc in $(get_dcs); do
    server=$(get_servers $dc)
    host=$(get_leader $server)
    echo $env $dc $host $(dig +short -x $host | sed 's/\.$//')
done