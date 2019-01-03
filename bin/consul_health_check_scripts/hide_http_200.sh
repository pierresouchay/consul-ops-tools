#!/bin/bash
# A shell script to avoid having
# very large checks output in Consul
# when everything is fine.
# When everything is fine (HTTP? 200),
# just output OK $URL
if test $# -lt 1
then
  echo "USAGE: $0 URL"
  exit 127
fi
output=$(mktemp)
curl -fs "$1" -o "$output"
res=$?
if test $res == 0
then
  echo "OK $1"
else
  echo "Res=$res for $1"
  cat "$output"
fi
rm "$output"
exit $res
