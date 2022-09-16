{ mysql -BN -e "select table_name from information_schema.tables where table_schema='mysql'" | while read -r tbl; do printf 'alter table `%s` placement policy test221;\n' "$tbl"; done; } | mysql mysql


CREATE PLACEMENT POLICY `test221` LEADER_CONSTRAINTS='["+topology.kubernetes.io/region=us-east-1",-topology.kubernetes.io/region=us-east-2]' FOLLOWER_CONSTRAINTS='{"+topology.kubernetes.io/region=us-east-1": 1, "+topology.kubernetes.io/region=us-east-2": 2, "+topology.kubernetes.io/region=us-west-2": 1}';

pd_ctl(){
    kubectl --context "${contexts[0]}" -n test-us-east-1 exec test-us-east-1-pd-0 -- /pd-ctl "$@"
}
pd_ctl config placement-rules rule-group set cluster_rule 100 true
pd_ctl config placement-rules rule-bundle set --in="cluster_rule_group.json"
kubectl --context "${contexts[0]}" -n test-us-east-1 exec test-us-east-1-pd-0 -i -- tee cluster_rule_group.json < cluster_rule_group.json
pd_ctl config placement-rules rule-bundle set --in="cluster_rule_group.json"
