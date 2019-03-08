#!/bin/bash

function usage {
  echo "USAGE: $0 [-l verbose|info|warn] NODE_TO_CHECK"
  echo "       This script checks that checks and services of a given node are in sync with the cluster."
  echo "       If it is not the case, it probably means an ACL is incorrect or that the node cannot sync"
  exit 254
}

if test $# -lt 1
then
  usage
  exit 254
fi

verbose=info
while getopts "l:m:h" option
do
  case $option in
    l)
      verbose=$OPTARG
      ;;
    h)
      usage
      ;;
  esac
done
shift $((OPTIND-1))
AGENT_ADDRESS=$1
nname=$(dig -x $AGENT_ADDRESS +short| grep -v -e '^$'||echo 'Cannot resolve Reverse')

tmp_file=$(mktemp)
curl --retry-connrefused --retry 1 --connect-timeout 9 -fs $AGENT_ADDRESS:8500/v1/agent/checks?pretty -o "$tmp_file"
if [ $? -ne 0 ]
then
  ping -c 1 -t 7 $AGENT_ADDRESS >/dev/null
  if [ $? -eq 0 ]
  then
    port_is_open=$(nc -z $AGENT_ADDRESS 8500 2>&1 || echo "Port 8500 is down")
    echo "[ERROR] Consul Agent $AGENT_ADDRESS seems down on $AGENT_ADDRESS:8500, but can ping it, FQDN: ${nname}, port status=$port_is_open"
    exit 250
  else
    echo "[ERROR] Machine $AGENT_ADDRESS is not reachable; FQDN: ${nname}"
    exit 251
  fi
fi
local_checks=$(jq -r '.[]|(.CheckID + ";"+ .Status)' "$tmp_file"  | tr ' ' '_')


curl -fs $AGENT_ADDRESS:8500/v1/health/node/${AGENT_ADDRESS}?pretty -o "$tmp_file"||echo '[]' > "$tmp_file"
if test '[]' = $(head -n1 "$tmp_file")
then
  curl --retry-connrefused --retry 3 -fsS $AGENT_ADDRESS:8500/v1/agent/self -o "$tmp_file" || { echo "[ERROR] Cannot guess node name for $AGENT_ADDRESS"; exit 252; }
  node_name=$(jq -r ".Member.Name" "$tmp_file")
  if test $verbose = "verbose"
  then
    echo "[ INFO ] found node name=${node_name} from $AGENT_ADDRESS:8500/v1/agent/self"
  fi
  curl --retry-connrefused --retry 3 -fs $AGENT_ADDRESS:8500/v1/health/node/${node_name}?pretty -o "$tmp_file" || { echo "[ERROR] Cannot find node ${node_name} in $AGENT_ADDRESS:8500/v1/health/node/${node_name}"; exit 253; }
fi

cluster_checks=$(jq -r '.[]|(.CheckID + ";"+ .Status)' "$tmp_file" | tr ' ' '_')
errors=0
errors_list=""
num_checks=$(echo $local_checks | wc -w | tr -d ' ')
if [ $num_checks -gt 600 ]
then
  echo "[ WARN ] there are $num_checks checks to validate for $AGENT_ADDRESS, script $0 might timeout"
fi
for check_s in $local_checks
do
  check_id=$(echo "$check_s"|cut -d \; -f1)
  found=0
  for k in $cluster_checks
  do
    if [[ "$k" =~ "$check_id;" ]]
    then
       found=1
       if [[ "$k" = "$check_s" ]]
       then
         if [[ "$verbose" = "verbose" ]]
         then
           echo "[  OK  ] for $check_id: LOCAL:$check_s VS $k"
         fi
       else
         if [[ "$verbose" != "warn" ]]
         then
           echo "[FAILED] for $check_id: LOCAL:$check_s VS $k"
         fi
         errors_list="$errors_list $check_id"
         errors=$((errors + 1))
       fi
       break
    fi
  done
  if [[ $found -eq 0 ]]
  then
    if [[ $verbose != "warn" ]]
    then
      echo "[FAILED] SERVICE $check_id MISSING in Cluster"
    fi
    errors_list="$errors_list '$(echo $check_id | tr '_' ' ')'"
    errors=$((errors + 1))
  fi
done
if test $verbose = "info"
then
  echo "[ INFO ] Services on agent $AGENT_ADDRESS: "$(echo $local_checks|tr ';' '\n'|wc -l)
  echo "[ INFO ] Services in cluster $AGENT_ADDRESS: "$(echo $cluster_checks|tr ';' '\n'|wc -l)
fi
if test $verbose = "verbose"
then
  echo "[ INFO ] Services on agent $AGENT_ADDRESS: $local_checks"
  echo "[ INFO ] Services in cluster $AGENT_ADDRESS: $cluster_checks"
fi
if test $errors = 0
then
  if test "$verbose" != "warn"
  then
    echo "[  OK  ] $AGENT_ADDRESS has No ERROR"
  fi
else
  echo "[FAILED] $AGENT_ADDRESS - $nname has $errors errors: $errors_list"
fi
exit $errors
