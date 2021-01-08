#!/bin/bash
if test ${1:-none} = "none"
then
  echo "USAGE: $0 Consul_URL"
  echo "       Example: localhost:8500/v1/health/service/MY_SUPER_SERVICE [query_param_option]"
  echo '       query_param_option is set by default to "&stale", ex: "&cached"'
  exit 1
fi
url_to_check=$1
qparams=${2:-"&stale"}

headers=$(mktemp)
color_diff=$(which colordiff 2>/dev/null ||which cdiff 2>/dev/null ||echo diff)
content=$(mktemp)
index=0
while true;
do
  url="${url_to_check}?wait=10m&index=${index}&pretty=true$qparams"
  curl -fs --dump-header "$headers" -o "${content}.new" "${url}" || { echo "Failed to query ${url}"; exit 1; }
  if test $index -ne 0
  then
    ${color_diff} -u "$content" "$content.new" && echo " diff: No Differences found in endpoint"
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

