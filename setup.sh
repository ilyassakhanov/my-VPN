#!/bin/bash

# Function to print help message
print_help() {
  echo "Usage:"
  echo "  $0 start --region eu-central-1"
  echo "  $0 stop"
  echo ""
  echo "Options:"
  echo "  --region    Which AWS region to create VPN to (only for 'start')"
  echo "  --help   Show this help message"
  exit 0
}

create_vpn_server() {
 # TODO: Import a subnet into tfstate
  TF_VAR_AZ=$(aws ec2 describe-subnets --region $REGION --query "Subnets[0].AvailabilityZone")
  SubnetID=$(aws ec2 describe-subnets --region $REGION --query "Subnets[0].SubnetId")

  # applying terraform
  cd ./terraform && terraform import aws_default_subnet.public_subnet1 $SubnetID
  terraform apply --auto-approve --var='AZ=${TF_VAR_AZ}'

  # setting server ip as a variable
  EC2_PUBLIC_IP=$(terraform output -raw web_instance_public_ip)

  # creating inventory for ansible
  cat <<EOF > ../ansible/inventory.ini
[webservers]
$EC2_PUBLIC_IP ansible_user=ec2-user ansible_ssh_private_key_file=$KEY_PATH
EOF
}

destroy_vpn_server() {
  # Destroying vpn server
  cd ./terraform && terraform destroy --target aws_instance.vpn_server --auto-approve
}

setup_vpn_server() {
  # Sets up a vpn server with ansible

  # Wiping old clients
  rm -rf ./clients/*

  # Disable are you sure you want to continue connecting
  export ANSIBLE_HOST_KEY_CHECKING=False
  # Setting up OpenVPN and pulling config
  cd ../ansible && ansible-playbook -i inventory.ini playbook.yml

  # Moving client to clients directory
  mv ../clients/client.ovpn/*/home/ec2-user/client.ovpn ../clients/my-client.ovpn
}

# No arguments? Show help and exit
if [[ $# -eq 0 ]]; then
  echo "❌ No arguments provided."
  print_help
fi

# Parse the command (first argument)
COMMAND="$1"
shift

KEY_PATH=""

# Parse arguments
case "$COMMAND" in
  start)
    # Parse additional flags
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
          echo "❌ Unknown option for 'start': $1"
          print_help
          ;;
      esac
    done

# Checking if key is provided
 if [[ -z $REGION ]]; then
    echo "❌ --region requires an AWS region name."
    print_help
    exit 1;
  fi


    echo "🟢 Spinning up VPN server"
    create_vpn_server
    # Give some time for a server to be configured by AWS
    sleep 15
    setup_vpn_server
    ;;

  stop)
    if [[ $# -gt 0 ]]; then
      echo "❌ 'stop' does not take any arguments."
      print_help
    fi
    echo "🔴 Stopping..."
    # Destroynig vpn server
    destroy_vpn_server
    ;;

  --help|-h)
    print_help
    ;;

  *)
    echo "❌ Unknown command: $COMMAND"
    print_help
esac


