desc_routes(){
    local region=$1
    aws --region="$region" ec2 describe-route-tables --filter Name=tag:"eksctl.cluster.k8s.io/v1alpha1/cluster-name",Values="test-$region"
}

del_route(){
    local region=$1
    local table=$2
    shift 2
    for cidr in "$@"
    do
        aws --region="$region" ec2 delete-route --route-table-id "$r" --destination-cidr-block "$cidr"
    done
}

isolate_east2(){
    local region=us-east-2
    desc_routes "$region" |
    jq -r '.RouteTables[] | select(.Routes | any(.DestinationCidrBlock=="10.100.0.0/16" or .DestinationCidrBlock=="10.102.0.0/16")) | .RouteTableId' |
    while read -r r
    do
        echo "$r"
        del_route "$region" "$r" "10.100.0.0/16" "10.102.0.0/16"
    done
}

restore_east2(){
    local region=us-east-2
    desc_routes "$region" |
    jq -r '.RouteTables[] | select(.Tags | any(.Key=="aws:cloudformation:logical-id" and (.Value|startswith("Private")))) | .RouteTableId' |
    while read -r r
    do
        aws --region="$region" ec2 create-route --route-table-id "$r" --destination-cidr-block "10.100.0.0/16" --vpc-peering-connection-id pcx-098f1e7ddfbe8f9c3
        aws --region="$region" ec2 create-route --route-table-id "$r" --destination-cidr-block "10.102.0.0/16" --vpc-peering-connection-id pcx-04700c30dc0949d56
    done
}

isolate_east1_from_east2(){
    local region=us-east-1
    desc_routes "$region" |
    jq -r '.RouteTables[] | select(.Routes | any(.DestinationCidrBlock=="10.101.0.0/16")) | .RouteTableId' |
    while read -r r
    do echo "$r"
        del_route "$region" "$r" "10.101.0.0/16"
    done
}

restore_east1_from_east2(){
    local region=us-east-1
    desc_routes "$region" |
    jq -r '.RouteTables[] | select(.Tags | any(.Key=="aws:cloudformation:logical-id" and (.Value|startswith("Private")))) | .RouteTableId' |
    while read -r r
    do
        aws --region="$region" ec2 create-route --route-table-id "$r" --destination-cidr-block "10.101.0.0/16" --vpc-peering-connection-id pcx-098f1e7ddfbe8f9c3
    done
}
