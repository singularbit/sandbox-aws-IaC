provider "aws" {
  region = "eu-west-1"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}

# Subnets
resource "aws_subnet" "my_subnet1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "MySubnet1"
  }
}

resource "aws_subnet" "my_subnet2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "MySubnet2"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.my_subnet1.id, aws_subnet.my_subnet2.id]

  tags = {
    Name = "MyDBSubnetGroup"
  }
}

# Security Group
resource "aws_security_group" "my_db_security_group" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MyDBSecurityGroup"
  }
}

# RDS Instance
resource "aws_db_instance" "my_db_instance" {
  allocated_storage       = 20
  engine                  = "mysql"
  instance_class          = "db.t2.micro"
  db_name                 = "mydatabase"
  username                = "admin"
  password                = "admin123"
  backup_retention_period = 7
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.my_db_security_group.id]
  db_subnet_group_name    = aws_db_subnet_group.my_db_subnet_group.name

  tags = {
    Name = "MyDBInstance"
  }
}
