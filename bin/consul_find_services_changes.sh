#!/bin/bash
if test ${1:-none} = "none"
then
  echo "USAGE: $0 Consul_URL"
  echo "       Example: localhost:8500"
  exit 1
fi
url_to_check=$1

diff=$(which colordiff || which diff || 'diff')
headers=$(mktemp)
content=$(mktemp)
index=0
while true;
do
  url="${url_to_check}/v1/catalog/services?wait=5m&index=${index}&pretty=true&stale"
  curl -fs --dump-header "$headers" "${url}" | jq keys[] -r|sort > "${content}.new" || { echo "Failed to query ${url}"; exit 1; }
  if test $index -ne 0
  then
    $diff "$content" "$content.new" && printf " diff: No Differences found in service\r"
  fi
  index=$(grep "X-Consul-Index" "$headers" | sed 's/[^0-9]*\([0-9][0-9]*\)[^0-9]*/\1/g')
  if test "${index:-not_found}" = "not_found"
  then
    # We are in a part of Consul that does not output X-Consul-Index in headers, switch to poll
    sleep 5
    index=1
  fi
  if test ${CONSUL_SLEEP_DELAY:-0} -gt 0
  then
    sleep ${CONSUL_SLEEP_DELAY}
  fi
  mv "$content.new" "$content"
  printf "X-Consul-Index: $index at $(date) \b"
done

