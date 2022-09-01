#!/bin/bash

# This sets up 9 tikv servers, 1 pd server 1 tikv server.
# The tikv servers have labels applied, which are then used with a placement rule.

# I am using a combination of source and binary for required programs
# Feel free to edit these locations for your system.
PDSERVER="/home/morgo/go/src/github.com/tikv/pd/bin/pd-server"
PDCTL="/home/morgo/go/src/github.com/tikv/pd/bin/pd-ctl"
TIDBSERVER="/home/morgo/go/src/github.com/morgo/tidb/bin/tidb-server"
TIKVSERVER="/home/morgo/.tiup/components/tikv/v6.2.0/tikv-server"

# Everything goes in here
# Note: TESTPREFIX/data and TESTPREFIX/logs will be wiped as part of this script!
TESTPREFIX="/mnt/evo970"

# -------------------------

set -x

killall -9 pd-server
killall -9 tikv-server
killall -9 tidb-server
killall -9 etcd
killall -9 grafana-server
sleep 3

rm -rf $TESTPREFIX/data/*
rm -rf $TESTPREFIX/logs/*
mkdir -p $TESTPREFIX/logs
mkdir -p $TESTPREFIX/data

# catch stale logs
cd $TESTPREFIX/logs

rm -rf /tmp/1000_tidb*
rm -rf /tmp/1000_TIKV*
rm -rf /tmp/tidb*

# You can start tidb and pd in any order.
# Lets start them first
$TIDBSERVER --store=tikv --path="127.0.0.1:2379" &
$PDSERVER --data-dir=$TESTPREFIX/data/pd --log-file=$TESTPREFIX/logs/pd.log &

# Start 9 tikv servers
# They will have labels for their region and zone
for i in `seq 1 9`; do
 REGION="us-east-1"
 if [ $i -gt 3 ]; then REGION="us-east-2"; fi
 if [ $i -gt 6 ]; then REGION="us-west-2"; fi

 mkdir -p $TESTPREFIX/data/tikv$i
 CONFIG="$TESTPREFIX/etc/config$i.toml"
 echo "[server]" > $CONFIG
 echo "labels = {region = \"$REGION\", zone = \"${REGION}a\", disk = \"ssd\" }" >> $CONFIG
 $TIKVSERVER --pd="127.0.0.1:2379" --data-dir=$TESTPREFIX/data/tikv$i -A 127.0.0.1:2016$i --log-file=$TESTPREFIX/logs/tikv$i.log --config=$CONFIG &
done;

sleep 10

# Adjust us-east-2 stores to have zero-weight for leaders
# This region is for quorum and not intended to server traffic.
for STORE in `mysql -BNe "SELECT store_id FROM information_schema.tikv_store_status WHERE address IN ('127.0.0.1:20164', '127.0.0.1:20165', '127.0.0.1:20166');"`; do
 $PDCTL store weight $STORE 0 1
done

sleep 3

# Create the base placement policy 
mysql -e "CREATE PLACEMENT POLICY defaultpolicy LEADER_CONSTRAINTS=\"[+region=us-east-1]\" FOLLOWER_CONSTRAINTS=\"{+region=us-east-1: 1,+region=us-east-2: 2,+region=us-west-2: 1}\";"
mysql -e "ALTER DATABASE test PLACEMENT POLICY=defaultpolicy;"

# Alter the mysql system tables to use the placement rule too
# This is because SHOW VARIABLES reads from a tikv table for the gc variables.
mysql -e "ALTER DATABASE mysql PLACEMENT POLICY=defaultpolicy;"
for TABLE in `mysql mysql -BNe "SHOW TABLES"`; do
 mysql mysql -e "ALTER TABLE $TABLE PLACEMENT POLICY=defaultpolicy;"
done; 

# Create our test table, keep loading data into it in a loop
mysql test -e "CREATE TABLE t1 (a INT NOT NULL PRIMARY KEY auto_increment, b varbinary(1024));"
mysql test -e "INSERT INTO t1 SELECT NULL, RANDOM_BYTES(1024) FROM dual;"

while true; do 
 mysql test -e "INSERT INTO t1 SELECT NULL, RANDOM_BYTES(1024) FROM t1 a JOIN t1 b JOIN t1 c LIMIT 50000";
done;
