#!/usr/bin/env bash

desc_routes(){
    local region=$1
    local cluster_name="test-$region"
    aws --region="$region" ec2 describe-route-tables --filter Name=tag:"eksctl.cluster.k8s.io/v1alpha1/cluster-name",Values="$cluster_name" |
        jq -r '.RouteTables[] | select(.Tags | any(.Key=="aws:cloudformation:logical-id" and (.Value|startswith("Private")))) | .RouteTableId' 
}

declare -A cidrs=(
    [us-east-1]="10.100.0.0/16"
    [us-east-2]="10.101.0.0/16"
    [us-west-2]="10.102.0.0/16"
)
declare -A routes=(
    [us-east-1.us-east-2]=pcx-098f1e7ddfbe8f9c3
    [us-east-1.us-west-2]=pcx-08062264271f3d12c
    [us-east-2.us-east-1]=pcx-098f1e7ddfbe8f9c3
    [us-east-2.us-west-2]=pcx-04700c30dc0949d56
    [us-west-2.us-east-1]=pcx-08062264271f3d12c
    [us-west-2.us-east-2]=pcx-04700c30dc0949d56
)

del_route(){
    local region=$1
    local table=$2
    shift 2
    for cidr in "$@"
    do
        aws --region="$region" ec2 delete-route --route-table-id "$table" --destination-cidr-block "$cidr"
    done
}

isolate_region(){
    local region=$1
    shift
    declare -a peers=("$@")
    if ! (( ${#peers[@]} ))
    then
        for peer in "${!cidrs[@]}"
        do
            [[ "$peer" == "$region" ]] || peers+=("$peer")
        done
    fi

    local table
    desc_routes "$region" |
        while read -r table
        do
            for peer in "${peers[@]}"
            do
                echo "$region $table ${cidrs[$peer]}"
                del_route "$region" "$table" "${cidrs[$peer]}"
            done
        done

}

restore_region(){
    #set -x
    local region=$1
    shift
    declare -a peers
    for peer in "${!cidrs[@]}"
    do
        [[ "$peer" == "$region" ]] || peers+=("$peer")
    done

    local table
    desc_routes "$region" |
    while read -r table 
    do
        for peer in "${peers[@]}"
        do
            echo "$region $table ${cidrs[$peer]} ${routes["$region.$peer"]}"
            aws --region="$region" ec2 create-route --route-table-id "$table" --destination-cidr-block "${cidrs["$peer"]}" --vpc-peering-connection-id "${routes["$region.$peer"]}"
        done
    done
    #set +x
}



#
## jq -r '.RouteTables[] | select(.Routes | any(.DestinationCidrBlock=="10.100.0.0/16" or .DestinationCidrBlock=="10.102.0.0/16")) | .RouteTableId' |
#isolate_east2(){
#    local region=us-east-2
#    desc_routes "$region" |
#    while read -r table
#    do
#        echo "$table"
#        del_route "$region" "$table" "10.100.0.0/16" "10.102.0.0/16"
#    done
#}
#
#restore_east2(){
#    set -x
#    local region=us-east-2
#    local table
#    desc_routes "$region" |
#    while read -r table 
#    do
#        for peer in us-east-1 us-west-2
#        do
#            aws --region="$region" ec2 create-route --route-table-id "$table" --destination-cidr-block "${cidrs["$peer"]}" --vpc-peering-connection-id "${routes["$region.$peer"]}"
#        done
#    done
#    set +x
#}
#
##    jq -r '.RouteTables[] | select(.Routes | any(.DestinationCidrBlock=="10.101.0.0/16")) | .RouteTableId' |
#isolate_east1_from_east2(){
#    local region=us-east-1
#    local table
#    desc_routes "$region" |
#    while read -r table
#    do
#        echo "$table"
#        del_route "$region" "$table" "10.101.0.0/16"
#    done
#}
#
##    jq -r '.RouteTables[] | select(.Tags | any(.Key=="aws:cloudformation:logical-id" and (.Value|startswith("Private")))) | .RouteTableId' |
#restore_east1_from_east2(){
#    local region=us-east-1
#    desc_routes "$region" |
#    while read -r table
#    do
#        aws --region="$region" ec2 create-route --route-table-id "$table" --destination-cidr-block "10.101.0.0/16" --vpc-peering-connection-id pcx-098f1e7ddfbe8f9c3
#    done
#}
