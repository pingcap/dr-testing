#!/usr/bin/env bash

# source this file, then you can use the isolate_region and restore_region shell commands
# set cluster_name in the desc_routes function according to your own scheme
# set the cidrs for your regions' VPCs in the "cidrs" associative array
# set the VPC peering connection IDs in the routes associative array

desc_routes(){
    local region=$1
    local cluster_name="test-$region"
    aws --region="$region" ec2 describe-route-tables --filter Name=tag:"eksctl.cluster.k8s.io/v1alpha1/cluster-name",Values="$cluster_name" |
        jq -r '.RouteTables[] | select(.Tags | any(.Key=="aws:cloudformation:logical-id" and (.Value|startswith("Private")))) | .RouteTableId' 
}

source ./eks_environment || exit


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
    usage="first argument should be the region whose routing tables you want to manipulate
other (optional) arguments should be the regions you want to remove from the first region's routing tables
if only one argument is given, remove all the routes to peers from its routing tables"
    if ! [[ $1 ]]
    then
        echo >&2 "$usage"
        return 1
    fi

    local region=$1
    shift

    if ! [[ "${cidrs[$region]}" ]]
    then
        echo >&2 "region $region is not supported"
        return 1
    fi

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
    usage="first argument should be the region whose routing tables you want to restore
the function will just try to create all routes for all peer regions across all Private subnets"
    if ! [[ $1 ]]
    then
        echo >&2 "$usage"
        return 1
    fi

    local region=$1
    shift

    if ! [[ "${cidrs[$region]}" ]]
    then
        echo >&2 "region $region is not supported"
        return 1
    fi

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
}
