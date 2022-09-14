use INFORMATION_SCHEMA

with store_count as (Select p.STORE_ID as store_id,p.IS_LEADER as is_leader,count(p.REGION_ID) as count from INFORMATION_SCHEMA.TIKV_REGION_PEERS p, INFORMATION_SCHEMA.TIKV_REGION_STATUS r where p.region_id=r.region_id and r.table_name="t3" and r.db_name="sysbench" group by p.STORE_ID,p.IS_LEADER)
select c.IS_LEADER,c.store_id,c.count,substring(s.ADDRESS,1,20) as address,s.STORE_STATE_NAME from TIKV_STORE_STATUS s,store_count c where c.store_id=s.store_id;