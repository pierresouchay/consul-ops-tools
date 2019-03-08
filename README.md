# consul-ops-tools

Simple Scripts to administrate/debug Consul

 * `check_consul_consistency.sh` Checks that a node is in sync with cluster
 * `bin/consul_node_id.rb` Generate a predictible node-id for a machine
 * `bin/consul_check_services_changes.sh` Watch changes on a Consul Endpoint and
   display a nice diff when values do change
 * `bin/consul_health_check_scripts/hide_http_200.sh` a script to hide output of
   HTTP HealthChecks that are too large with HTTP Code 200 and limit raft
   database grows for large clusters.
