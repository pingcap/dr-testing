#!/usr/bin/env bash

declare -a contexts=(
    [0]="kolbe@test-us-east-1.us-east-1.eksctl.io"
    [1]="kolbe@test-us-east-2.us-east-2.eksctl.io"
    [2]="kolbe@test-us-west-2.us-west-2.eksctl.io"
)
declare -A C=(
    [kolbe@test-us-east-2.us-east-2.eksctl.io]="test-us-east-2"
    [kolbe@test-us-east-1.us-east-1.eksctl.io]="test-us-east-1"
    [kolbe@test-us-west-2.us-west-2.eksctl.io]="test-us-west-2"
)
declare -a regions=("us-east-1" "us-east-2" "us-west-2")

all_c () 
{ 
    for c in "${!C[@]}";
    do
        kubectl --context "$c" --namespace "${C[$c]}" "$@";
    done
}

printf -v dirname "logs-%(%s)T"

mkdir "$dirname" || exit

echo "$dirname"


for c in "${!C[@]}"
do
    n="${C[$c]}"
    echo "$n"
    kubectl --context "$c" -n "$n" get po -o json |
        jq --argjson components '["pd","tidb","tikv"]' -r \
        '.items[] | select(.metadata.labels."app.kubernetes.io/component" |
         IN($components[])) | "\(.metadata.name)\t\(.metadata.labels."app.kubernetes.io/component")"' |
        while read -r pod component
        do
            container=()
            [[ $component = tidb ]] && container=(-c tidb)
            kubectl --context "$c" -n "$n" "${container[@]}" exec "$pod" -- \
                gzip -c /var/log/"$component".log |
                gunzip - > "$dirname"/"$pod".log
        done
done

tar cvzf "$dirname.tgz" "$dirname"
