terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "b" {
  bucket = "garytoleenewtask"
  acl = "public-read"
}

resource "aws_s3_bucket" "newtaskgaltfstate" {
  bucket = "newtaskgaltfstate"
  acl = "private"
}

resource "aws_s3_bucket_policy" "b" {
  bucket = aws_s3_bucket.b.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "MYBUCKETPOLICY"
    Statement = [
      {
        Sid       = "Stmt1616319469899"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*",
        Resource = [
          aws_s3_bucket.b.arn,
          "${aws_s3_bucket.b.arn}/*",
        ]
        Condition = {
          IpAddress = {
            "aws:SourceIp" = "8.8.8.8/32"
          }
        }
      },
    ]
  })
}
resource "aws_s3_bucket_object" "object" {
  bucket = "garytoleenewtask"
  acl    = "public-read"
  key    = "userdata.sh"
  source = "userdata.sh"
  content_type = "text/html"
}

# # 1. Create vpc
resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dev"
  }
}

# # 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev-vpc.id


}

# # 3. Create Custom Route Table
resource "aws_route_table" "dev-route-table" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Dev"
  }
}

# # 4. Create a Subnet 
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "dev-subnet"
  }
}

# # 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.dev-route-table.id
}

# # 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    description = "HTTP"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# # 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# # 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# # 9. Create Ubuntu server
resource "aws_instance" "web-server-instance" {
  ami               = "ami-042e8287309f5df03" 
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  user_data = "sudo apt-get wget -y; wget https://garytoleenewtask.s3.amazonaws.com/userdata.sh; chmod 755 userdata.sh; ./userdata.sh"
 

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
}

output "server_private_ip" {
  value = aws_instance.web-server-instance.private_ip

}

output "server_id" {
  value = aws_instance.web-server-instance.id
}

resource "aws_s3_bucket_object" "newtaskgaltfstate" {
  bucket = "newtaskgaltfstate"
  acl    = "private"
  key    = "terraform.tfstate"
  source = "terraform.tfstate"
  content_type = "text/html"
}