# my-VPN

## Description
```
This code represents a tool that can create a VPN for personal use in a couple of seconds after setup.
And it will only cost you 1$ per year too!
```
### Preprequisites
```
AWS CLI
terraform
ansible
AWS account
OpenVPN client
```

### Setup
 - Set up your AWS CLI with AWS account
 - Generate your .pem key and update it in variable.tf
 - To minimize costs, use default VPC and subnets, internet gateway and route tables\
 To achieve that, use terraform plan & terraform import commands
 - Run commands to spin up your VPN
 ```
  ./setup.sh
 ```

 ### Connect to VPN
```
Choose my-client.ovpn file in clients directory
```

### Limitaions
 - Bandwidth is limited and it can be preety slow
 - You get what you pay for 
