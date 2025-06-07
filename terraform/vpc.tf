resource "aws_default_vpc" "default" {
  tags = {
    Name = "default"
  }

  lifecycle {
    prevent_destroy = true
  }
}



resource "aws_default_subnet" "public_subnet1" {
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "subnet1"
  }
}



resource "aws_default_subnet" "public_subnet2" {
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "subnet2"
  }
}



resource "aws_default_subnet" "public_subnet3" {
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "subnet3"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_default_vpc.default.id

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_default_vpc.default.id

  lifecycle {
    prevent_destroy = true
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "subnet1_route" {
  subnet_id      = aws_default_subnet.public_subnet1.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "subnet2_route" {
  subnet_id      = aws_default_subnet.public_subnet2.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "subnet3_route" {
  subnet_id      = aws_default_subnet.public_subnet3.id
  route_table_id = aws_route_table.route_table.id
}
