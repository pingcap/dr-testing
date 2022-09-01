# Can be used with
# mysql < check-placement.sql  | grep -v us-east-1
# -or-
# mysql < check-placement.sql  | grep us-east-1

use information_schema;
WITH store_index AS (SELECT store_id, substring(address, -1) as node_number, label->>"$[0].value" as aws_region from tikv_store_status)
SELECT
 node_number as node, aws_region, is_leader, count(*) as c
FROM tikv_region_peers
INNER JOIN TIKV_REGION_STATUS USING (region_id)
INNER JOIN store_index USING (store_id)
WHERE db_name = 'test'
GROUP BY
node_number, is_leader
ORDER BY node_number;

