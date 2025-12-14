# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-IGW"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}-Public-Subnet"
  }
}

# Private Subnet 1
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "${var.region}b"
  tags = {
    Name = "${var.name}-Private-Subnet-1"
  }
}

# Private Subnet 2
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "${var.region}c"
  tags = {
    Name = "${var.name}-Private-Subnet-2"
  }
}

# Allocate Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.name}-NAT-EIP"
  }
}

# Create NAT Gateway in the public subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "${var.name}-NAT-GW"
  }
  depends_on = [aws_internet_gateway.igw]
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-Public-RT"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route Table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.name}-Private-RT"
  }
}

# Associate Private Subnets with the Private Route Table
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}


# Security Groups
resource "aws_security_group" "public" {
  name        = "Public-Instance-SG"
  description = "Security group for public instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8081
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
    Name = "${var.name}-Public-Instance-SG"
  }
}

resource "aws_security_group" "private" {
  name        = "Private-Instance-SG"
  description = "Security group for private instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-Private-Instance-SG"
  }
}

# IAM Role for EC2 Instances
# resource "aws_iam_role" "ec2_role" {
#   name = "ec2_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ec2_ssm" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_instance_profile" "ec2_profile" {
#   name = "ec2_profile"
#   role = aws_iam_role.ec2_role.name
# }

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Public Instance
resource "aws_instance" "public" {
  ami                         = data.aws_ami.amazon_linux.id #"ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.public.id]
  associate_public_ip_address = true
  #iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.ec2_key.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              
              # Install Python and Flask for testing
              yum install python3 -y
              pip3 install flask
              
              # Configure Nginx as reverse proxy
              cat > /etc/nginx/conf.d/reverse-proxy.conf << 'EOL'
              server {
                  listen 8080;
                  location / {
                      proxy_pass http://${aws_instance.private_1.private_ip}:5000;
                  }
              }

              server {
                  listen 8081;
                  location / {
                      proxy_pass http://${aws_instance.private_2.private_ip}:5000;
                  }
              }
              EOL
              
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "${var.name}-Public-Instance"
  }
}

# Private Instance 1
resource "aws_instance" "private_1" {
  ami                         = data.aws_ami.amazon_linux.id #"ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_1.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  associate_public_ip_address = false
  #iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.ec2_key.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install python3 -y
              pip3 install flask
              
              cat > /home/ec2-user/app.py << 'EOL'
              from flask import Flask
              app = Flask(__name__)

              @app.route('/')
              def hello():
                  return "Hello I am from Private-1 Instance"

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=5000)
              EOL

              chmod +x /home/ec2-user/app.py
              nohup python3 /home/ec2-user/app.py > /var/log/flask-app.log 2>&1 &
              EOF

  tags = {
    Name = "${var.name}-Private-Instance-1"
  }
}

# Private Instance 2
resource "aws_instance" "private_2" {
  ami                         = data.aws_ami.amazon_linux.id #"ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_2.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  associate_public_ip_address = false
  #iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = aws_key_pair.ec2_key.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install python3 -y
              pip3 install flask
              
              cat > /home/ec2-user/app.py << 'EOL'
              from flask import Flask
              app = Flask(__name__)

              @app.route('/')
              def hello():
                  return "Hello I am from Private-2 Instance"

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=5000)
              EOL

              chmod +x /home/ec2-user/app.py
              nohup python3 /home/ec2-user/app.py > /var/log/flask-app.log 2>&1 &
              EOF

  tags = {
    Name = "${var.name}-Private-Instance-2"
  }
}

# Key pair for SSH access
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.name}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Save private key to file
resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${path.module}/${var.name}-key.pem"
  file_permission = "0400"
}