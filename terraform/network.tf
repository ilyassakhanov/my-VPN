resource "aws_default_vpc" "default" {
  tags = {
    Name = "default"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_default_subnet" "public_subnet1" {
  availability_zone       = var.AZ
  map_public_ip_on_launch = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "subnet1"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH, HTTP, and OpenVPN traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpn-sg"
  }
}
