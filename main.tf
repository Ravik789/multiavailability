terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "private-app-vpc" }
}

# Public subnets: one in each AZ
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(["10.0.1.0/24", "10.0.3.0/24"], count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private subnets: one in each AZ
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(["10.0.2.0/24", "10.0.4.0/24"], count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "private-app-igw" }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "public-route-table" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ALB security group
resource "aws_security_group" "alb" {
  name        = "private-app-alb-sg"
  description = "Allow HTTP browser traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-app-alb-sg" }
}

# Private application security group
resource "aws_security_group" "app" {
  name        = "private-app-sg"
  description = "Allow application traffic only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-app-sg" }
}

# Application EC2 instances: one per AZ
resource "aws_instance" "app" {
  count                       = 2
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[count.index].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app.id]

  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /opt/private-app

    cat > /opt/private-app/index.html <<'HTML'
    <!DOCTYPE html>
    <html>
      <head><title>Multi-AZ Private App</title></head>
      <body>
        <h1>Hello from Private EC2!</h1>
        <p>Application is running in a private subnet.</p>
        <p>Availability Zone: ${element(var.availability_zones, count.index)}</p>
        <p>Instance number: ${count.index + 1}</p>
      </body>
    </html>
    HTML

    cat > /etc/systemd/system/private-app.service <<'SERVICE'
    [Unit]
    Description=Private VPC Demo Application
    After=network.target

    [Service]
    Type=simple
    WorkingDirectory=/opt/private-app
    ExecStart=/usr/bin/python3 -m http.server 8080 --bind 0.0.0.0 --directory /opt/private-app
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable --now private-app
  EOF

  tags = {
    Name = "private-app-ec2-${count.index + 1}"
  }
}

# Application Load Balancer across both public subnets
resource "aws_lb" "app" {
  name               = "private-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "private-app-alb" }
}

# Target group for private EC2 applications
resource "aws_lb_target_group" "app" {
  name     = "private-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "private-app-tg" }
}

# Register both EC2 instances
resource "aws_lb_target_group_attachment" "app" {
  count            = 2
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 8080
}

# HTTP listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
