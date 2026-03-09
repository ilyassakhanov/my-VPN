#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
CLIENTS_DIR="$SCRIPT_DIR/clients"

print_help() {
  echo "Usage:"
  echo "  $0 start [--region <aws-region>]  (default: eu-central-1)"
  echo "  $0 stop"
  echo ""
  echo "Options:"
  echo "  --region    AWS region to create VPN in (only for 'start')"
  echo "  --help      Show this help message"
  exit 0
}

# Returns the workspace name that has a running EC2 instance, or empty string
get_active_workspace() {
  pushd "$TERRAFORM_DIR" > /dev/null
  local found=""
  for workspace in $(terraform workspace list | sed 's/^\* //' | tr -d ' ' | grep -v '^$' | grep -v '^default$'); do
    terraform workspace select "$workspace" > /dev/null 2>&1
    if terraform state list aws_instance.vpn_server > /dev/null 2>&1; then
      instance_state=$(aws ec2 describe-instances \
        --region "$workspace" \
        --filters "Name=tag:Name,Values=vpn-server" "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].State.Name" \
        --output text 2>/dev/null)
      if [[ "$instance_state" == "running" ]]; then
        found="$workspace"
        break
      fi
    fi
  done
  popd > /dev/null
  echo "$found"
}

create_vpn_server() {
  TF_VAR_AZ=$(aws ec2 describe-subnets --region "$REGION" --query "Subnets[0].AvailabilityZone" --output text)
  SubnetID=$(aws ec2 describe-subnets --region "$REGION" --query "Subnets[0].SubnetId" --output text)

  pushd "$TERRAFORM_DIR" > /dev/null

  # Create or select a workspace for this region
  terraform workspace new "$REGION" 2>/dev/null || terraform workspace select "$REGION"

  IMPORT_VARS=(--var="AZ=$TF_VAR_AZ" --var="region=$REGION")

  # Import the default VPC if it isn't already tracked in this workspace's state
  if ! terraform state list aws_default_vpc.default > /dev/null 2>&1; then
    VpcID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)
    terraform import "${IMPORT_VARS[@]}" aws_default_vpc.default "$VpcID"
  fi

  # Import the default subnet if it isn't already tracked in this workspace's state
  if ! terraform state list aws_default_subnet.public_subnet1 > /dev/null 2>&1; then
    terraform import "${IMPORT_VARS[@]}" aws_default_subnet.public_subnet1 "$SubnetID"
  fi

  # Import the security group if it exists in AWS but not in state
  if ! terraform state list aws_security_group.web_sg > /dev/null 2>&1; then
    SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
      --filters "Name=group-name,Values=web-sg" \
      --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
    if [[ -n "$SG_ID" && "$SG_ID" != "None" ]]; then
      terraform import "${IMPORT_VARS[@]}" aws_security_group.web_sg "$SG_ID"
    fi
  fi

  # If the key pair exists in AWS but not in state, delete it so Terraform recreates it
  # (tls_private_key won't be in state either, so importing would cause a replace anyway)
  if ! terraform state list aws_key_pair.kp > /dev/null 2>&1; then
    if aws ec2 describe-key-pairs --region "$REGION" --key-names myKey > /dev/null 2>&1; then
      echo "Key pair 'myKey' exists in AWS but not in state — deleting so Terraform can recreate it."
      aws ec2 delete-key-pair --region "$REGION" --key-name myKey
    fi
  fi

  terraform apply --auto-approve --var="AZ=$TF_VAR_AZ" --var="region=$REGION" || {
    popd > /dev/null
    echo "Terraform apply failed. Aborting."
    exit 1
  }

  EC2_PUBLIC_IP=$(terraform output -raw web_instance_public_ip)

  if [[ ! -f "$KEY_PATH" ]]; then
    terraform output -raw private_key_pem > "$KEY_PATH"
    chmod 600 "$KEY_PATH"
  fi

  popd > /dev/null

  cat <<EOF > "$ANSIBLE_DIR/inventory.ini"
[webservers]
$EC2_PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH
EOF
}

destroy_vpn_server() {
  local region="$1"
  local az
  az=$(aws ec2 describe-subnets --region "$region" --query "Subnets[0].AvailabilityZone" --output text)
  pushd "$TERRAFORM_DIR" > /dev/null
  terraform destroy --target aws_instance.vpn_server --auto-approve --var="AZ=$az" --var="region=$region"
  popd > /dev/null
}

setup_vpn_server() {
  chmod 600 "$KEY_PATH"
  rm -rf "$CLIENTS_DIR"/*
  export ANSIBLE_HOST_KEY_CHECKING=False
  pushd "$ANSIBLE_DIR" > /dev/null
  ansible-playbook -i inventory.ini playbook.yml
  popd > /dev/null
  mv "$CLIENTS_DIR"/client.ovpn/*/home/ubuntu/myclient.ovpn "$CLIENTS_DIR/my-client.ovpn"
}

# No arguments? Show help and exit
if [[ $# -eq 0 ]]; then
  echo "No arguments provided."
  print_help
fi

COMMAND="$1"
shift

case "$COMMAND" in
  start)
    REGION=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --region)
          REGION="$2"
          shift 2
          ;;
        --help)
          print_help
          ;;
        *)
          echo "Unknown option for 'start': $1"
          print_help
          ;;
      esac
    done

    if [[ -z "$REGION" ]]; then
      REGION="eu-central-1"
      echo "No --region specified, defaulting to $REGION."
    fi

    KEY_PATH="$TERRAFORM_DIR/myKey-$REGION.pem"

    active=$(get_active_workspace)
    if [[ -n "$active" ]]; then
      echo "A VPN is already running in region: $active"
      echo "Run './setup.sh stop' before starting a new one."
      exit 1
    fi

    echo "Spinning up VPN in $REGION..."
    create_vpn_server
    sleep 15
    setup_vpn_server
    echo "Done. Import clients/my-client.ovpn into your OpenVPN client."
    ;;

  stop)
    if [[ $# -gt 0 ]]; then
      echo "'stop' does not take any arguments."
      print_help
    fi

    active=$(get_active_workspace)
    if [[ -z "$active" ]]; then
      echo "No VPN is currently running."
      exit 1
    fi

    echo "Stopping VPN in region: $active..."
    pushd "$TERRAFORM_DIR" > /dev/null
    terraform workspace select "$active"
    popd > /dev/null
    destroy_vpn_server "$active"
    echo "VPN stopped."
    ;;

  --help|-h)
    print_help
    ;;

  *)
    echo "Unknown command: $COMMAND"
    print_help
    ;;
esac
