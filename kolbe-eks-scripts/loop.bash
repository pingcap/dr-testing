#!/usr/bin/env bash

trap 'exit 0' SIGINT

host=a38cf6fd1763946b8ba4c5c5c3272dfa-da992c5fba84d563.elb.us-east-1.amazonaws.com

mysql(){
    command mysql -h "$host" -P 4000 -u root "$@" > /dev/null
}

sql_select(){
    # printf 'select * from test.t1 where id=%i;\n' "$(( ( SRANDOM ) % 41275272 ))"
    printf 'select * from test.t1 where c=%i limit 1;\n' "$(( ( SRANDOM ) % 1000 ))"
}

sql_insert(){
    printf 'insert into test.t1 (c) values (%i);\n' "$1";
}

j=0
while true
do
    echo "$((j++))"
    time {
        {
            printf 'set autocommit=0;\n'
            for ((i=0;i<1000;i++))
            do
                printf "show variables like 'query_cache_type';\n"
                sql_"$1" "$i"
                printf 'commit;\n'
            done
        } |
        mysql
    }
done
