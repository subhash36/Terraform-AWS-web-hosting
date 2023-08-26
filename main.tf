resource "aws_vpc" "vpc_av_cc" {
  cidr_block = var.cidr

  tags = {
    Name = "vpc-av-cc"
  }
}

resource "aws_subnet" "subnet_1_av_cc" {
  vpc_id                  = aws_vpc.vpc_av_cc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-1-av-cc"
  }
}

resource "aws_subnet" "subnet_2_av_cc" {
  vpc_id                  = aws_vpc.vpc_av_cc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-2-av-cc"
  }
}

resource "aws_internet_gateway" "ig_av_cc" {
  vpc_id = aws_vpc.vpc_av_cc.id

  tags = {
    Name = "ig-av-cc"
  }
}

resource "aws_route_table" "rt_av_cc" {
  vpc_id = aws_vpc.vpc_av_cc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_av_cc.id
  }

  tags = {
    Name = "rt-av-cc"
  }
}

resource "aws_route_table_association" "rt_a_av_cc" {
  subnet_id      = aws_subnet.subnet_1_av_cc.id
  route_table_id = aws_route_table.rt_av_cc.id
}

resource "aws_route_table_association" "rt_b_av_cc" {
  subnet_id      = aws_subnet.subnet_2_av_cc.id
  route_table_id = aws_route_table.rt_av_cc.id
}

resource "aws_security_group" "sg_av_cc" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc_av_cc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-av-cc"
  }
}

resource "aws_s3_bucket" "name" {
  bucket = "s3-av-cc"
}

resource "aws_instance" "ec2_1_av_cc" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg_av_cc.id]
  subnet_id              = aws_subnet.subnet_1_av_cc.id
  user_data              = base64encode(file("userdata.sh"))

  tags = {
    Name = "ec2_1_av_cc"
  }
}

resource "aws_instance" "ec2_2_av_cc" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg_av_cc.id]
  subnet_id              = aws_subnet.subnet_2_av_cc.id
  user_data              = base64encode(file("userdata-cc.sh"))

  tags = {
    Name = "ec2_2_av_cc"
  }
}

resource "aws_lb" "alb_av_cc" {
  name               = "alb-av-cc"
  internal           = false // is the lb public or private. internal=private
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_av_cc.id]
  subnets            = [aws_subnet.subnet_1_av_cc.id, aws_subnet.subnet_2_av_cc.id]

  tags = {
    Environment = "alb-av-cc"
  }
}

resource "aws_lb_target_group" "tg_av_cc" {
  name     = "tg-av-cc"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_av_cc.id

  health_check {
    path              = "/"
    port              = "traffic-port"
    healthy_threshold = 5

  }
}

resource "aws_lb_target_group_attachment" "attach_1_av_cc" {
  target_group_arn = aws_lb_target_group.tg_av_cc.arn
  target_id        = aws_instance.ec2_1_av_cc.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach_2_av_cc" {
  target_group_arn = aws_lb_target_group.tg_av_cc.arn
  target_id        = aws_instance.ec2_2_av_cc.id
  port             = 80
}

resource "aws_lb_listener" "listen_av_cc" {
  load_balancer_arn = aws_lb.alb_av_cc.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg_av_cc.arn
    type             = "forward"
  }
}

output "lb-dns-name" {
  value = aws_lb.alb_av_cc.dns_name
}