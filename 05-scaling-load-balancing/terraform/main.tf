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

# Security Group for Load Balancer
resource "aws_security_group" "my_lb_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MyLoadBalancerSecurityGroup"
  }
}

# Security Group for EC2 Instances
resource "aws_security_group" "my_instance_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.my_lb_sg.id]
  }

  tags = {
    Name = "MyInstanceSecurityGroup"
  }
}

# Application Load Balancer
resource "aws_lb" "my_lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_lb_sg.id]
  subnets            = [aws_subnet.my_subnet1.id, aws_subnet.my_subnet2.id]

  enable_deletion_protection = false

  tags = {
    Name = "MyLoadBalancer"
  }
}

# Target Group
resource "aws_lb_target_group" "my_target_group" {
  name        = "my-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    port                = "80"
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-299"
  }

  tags = {
    Name = "MyTargetGroup"
  }
}

# Listener
resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Launch Configuration
resource "aws_launch_configuration" "my_launch_configuration" {
  name          = "my-launch-configuration"
  image_id      = "ami-0b995c42184e99f98" # Replace with a valid AMI ID
  instance_type = "t2.micro"
  security_groups = [aws_security_group.my_instance_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              service httpd start
              chkconfig httpd on
              EOF
}

# Auto Scaling Group
resource "aws_autoscaling_group" "my_asg" {
  vpc_zone_identifier = [aws_subnet.my_subnet1.id, aws_subnet.my_subnet2.id]
  launch_configuration = aws_launch_configuration.my_launch_configuration.name
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  health_check_type    = "EC2"
  health_check_grace_period = 300

  target_group_arns = [aws_lb_target_group.my_target_group.arn]

  tag {
    key                 = "Name"
    value               = "MyAutoScalingGroup"
    propagate_at_launch = true
  }
}
