provider "aws" {
  region = "eu-west-1"
}

resource "aws_instance" "my_ec2_instance" {
  ami           = "ami-0b995c42184e99f98"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.my_security_group.id]
}

resource "aws_security_group" "my_security_group" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}