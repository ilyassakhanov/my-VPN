#!/bin/bash

# Applying Terraform
cd ./terraform && terraform apply --auto-approve

# Setting server IP as a variable
EC2_PUBLIC_IP=$(terraform output -raw web_instance_public_ip)

# Creating Inventory for ansible
cat <<EOF > ../ansible/inventory.ini
[webservers]
$EC2_PUBLIC_IP ansible_user=ec2-user ansible_ssh_private_key_file=
EOF


sleep 15

# Wiping old clients
rm -rf ../clients/*


# Setting up OpenVPN and pulling config
cd ../ansible && ansible-playbook -i inventory.ini playbook.yml

# Moving client to clients directory
mv ../clients/client.ovpn/*/home/ec2-user/client.ovpn ../clients/my-client.ovpn

