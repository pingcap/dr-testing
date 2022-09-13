export AWS_PROFILE=pingcap
declare -A C=(
    [kolbe@test-us-east-2.us-east-2.eksctl.io]="test-us-east-2"
    [kolbe@test-us-east-1.us-east-1.eksctl.io]="test-us-east-1"
    [kolbe@test-us-west-2.us-west-2.eksctl.io]="test-us-west-2"
)
declare -a regions=([0]="us-east-1" [1]="us-east-2" [2]="us-west-2")

for r in "${regions[@]}"
do
    eksctl --region="$r" scale nodegroup --cluster=test-"$r" admin-"$r" -N 1
    eksctl --region="$r" scale nodegroup --cluster=test-"$r" pd-"$r" -N 1
    for n in tikv-"${r/us-/}"{a,b,c,d}
    do
        eksctl --region="$r" scale nodegroup --cluster=test-"$r" "$n" -N 2
    done
    for n in tidb-"$r"{a,c}
    do
        eksctl --region="$r" scale nodegroup --cluster=test-"$r" "$n" -N 1
    done
done

while ! read -r -n1 -t1
do
    for c in "${!C[@]}"
    do
        echo "press any key to continue"
        kubectl --context="$c" get nodes
        echo
    done
done

for c in "${!C[@]}"
do
    re='.*@([^.]+)\.'
    [[ $c =~ $re ]]
    cluster="${BASH_REMATCH[1]}"
    echo "$cluster"
    kubectl --context "$c" -n "${C[$c]}" patch tc "$cluster" -p '{"spec":{"suspendAction":{"suspendStatefulSet":false}}}' --type=merge
done

while ! read -r -n1 -t1
do
    echo "press any key to continue"
    for c in "${!C[@]}"
    do
        kubectl --context "$c" -n "${C[$c]}" get po
    done
    echo
done
