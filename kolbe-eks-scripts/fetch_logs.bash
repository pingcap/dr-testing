#!/usr/bin/env bash

source ./eks_environment || exit

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

destfile="$dirname.tgz"
tar cvzf "$destfile" "$dirname"
open -R "$destfile"
