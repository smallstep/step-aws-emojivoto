# Create a VPC for our application
resource "aws_vpc" "emojivoto" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "emojivoto"
  }
}

resource "aws_vpc_dhcp_options" "emojivoto" {
  domain_name         = "emojivoto.local"
  domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "emojivoto" {
  vpc_id          = "${aws_vpc.emojivoto.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.emojivoto.id}"
}

# Create a VPC subnet, we will use this subnet with an internet gateway to allow
# public traffic
resource "aws_subnet" "emojivoto" {
  vpc_id     = "${aws_vpc.emojivoto.id}"
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "emojivoto"
  }
}

# Create a security group resource to allow SSH, TLS, and Puppet traffic
resource "aws_security_group" "emojivoto" {
  name        = "emojivoto"
  description = "Allow SSH, TLS, and Puppet inbound traffic"
  vpc_id      = "${aws_vpc.emojivoto.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow internal TLS traffic"
  }

  ingress {
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow internal puppet traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow any outbound traffic"
  }

  tags = {
    Name = "emojivoto"
  }
}

resource "aws_security_group" "emojivoto_web" {
  name        = "emojivoto_web"
  description = "Allow TLS traffic"
  vpc_id      = "${aws_vpc.emojivoto.id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow external TLS traffic"
  }

  tags = {
    Name = "emojivoto-web"
  }
}


resource "aws_internet_gateway" "emojivoto" {
  vpc_id = "${aws_vpc.emojivoto.id}"
  tags = {
    Name = "emojivoto"
  }
}

resource "aws_route_table" "emojivoto" {
  vpc_id = "${aws_vpc.emojivoto.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.emojivoto.id}"
  }
  tags = {
    Name = "emojivoto"
  }
}

resource "aws_route_table_association" "emojivoto" {
  subnet_id      = "${aws_subnet.emojivoto.id}"
  route_table_id = "${aws_route_table.emojivoto.id}"
}
