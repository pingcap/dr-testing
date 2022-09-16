#!/usr/bin/env bash

source ./eks_environment || exit

for c in "${!C[@]}"
do
    re='.*@([^.]+)\.'
    [[ $c =~ $re ]]
    cluster="${BASH_REMATCH[1]}"
    echo "$cluster"
    kubectl --context "$c" -n "${C[$c]}" patch tc "$cluster" -p '{"spec":{"suspendAction":{"suspendStatefulSet":true}}}' --type=merge
done

while ! read -rn1 -t1
do
    echo "press any key to continue"
    for c in "${!C[@]}"
    do
        kubectl --context "$c" -n "${C[$c]}" get po
    done
    echo
done

for r in "${regions[@]}"
do
    for n in tidb-"$r"{a,b,c,d}
    do
        eksctl --region="$r" scale nodegroup --cluster=test-"$r" "$n" -N 0 -m 0
    done
    for n in tikv-"${r/us-/}"{a,b,c,d}
    do
        eksctl --region="$r" scale nodegroup --cluster=test-"$r" "$n" -N 0 -m 0
    done
    eksctl --region="$r" scale nodegroup --cluster=test-"$r" pd-"$r" -N 0 -m 0
    eksctl --region="$r" scale nodegroup --cluster=test-"$r" admin-"$r" -N 0 -m 0
done

aws ec2 stop-instances --region=us-east-1 --instance-ids i-08906de8d4401fc69

while ! read -rn1 -t1
do
    for c in "${!C[@]}"
    do
        kubectl --context="$c" get nodes
    done
done

