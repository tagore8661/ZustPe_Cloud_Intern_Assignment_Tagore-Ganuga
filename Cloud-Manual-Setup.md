# Creating Infra Manually by using AWS Console
Create this infrastructure using AWS manual steps

## Create VPC
1. Go to AWS Management Console → VPC
2. Click "Create VPC"
3. Select "VPC and more" (for simplicity)
4. Configure:
  - Name tag: ZustPe-VPC
  - IPv4 CIDR: 10.0.0.0/16
  - Enable DNS hostnames: Yes
  - Tenancy: Default

## Create Subnets
1. In the VPC dashboard, go to "Subnets"
2. Create 3 subnets:
  **Public Subnet:**
  - Name: ZustPe-Public-Subnet
  - VPC: Select your VPC
  - Availability Zone: us-east-1a
  - IPv4 CIDR: 10.0.1.0/24
  - Auto-assign public IPv4: Yes
  **Private Subnet 1:**
  - Name: ZustPe-Private-Subnet-1
  - VPC: Select your VPC
  - Availability Zone: us-east-1b
  - IPv4 CIDR: 10.0.2.0/24
  **Private Subnet 2:**
  - Name: ZustPe-Private-Subnet-2
  - VPC: Select your VPC
  - Availability Zone: us-east-1c
  - IPv4 CIDR: 10.0.3.0/24

## Create Internet Gateway
  - In VPC dashboard, go to "Internet Gateways"
  - Click "Create internet gateway"
  - Name: ZustPe-IGW
  - Click "Create internet gateway"
  - Select the IGW → Actions → Attach to VPC → Select your VPC

## Create NAT Gateway
1. Allocate an **Elastic IP**:
  - Go to VPC Console → Elastic IPs → Allocate Elastic IP.
  - Click Allocate.
2. Create NAT Gateway:
  - Go to VPC Console → NAT Gateways → Create NAT Gateway.
  - Name: ZustPe-NAT-GW
  - Subnet: Select ZustPe-Public-Subnet
  - Elastic IP: Select the EIP you just created.
  - Click Create NAT Gateway.

## Create Route Tables
1. Public Route Table:
  - Go to "Route Tables"
  - Create route table
  - Name: ZustPe-Public-RT
  - VPC: Select your VPC
  - Edit routes → Add route
    - Destination: 0.0.0.0/0
    - Target: Select your IGW
  - Save changes
  - Go to "Subnet associations" → Edit → Add ZustPe-Public-Subnet
2. Private Route Tables:
  - Create Route Table → Name: ZustPe-Private-RT
  - VPC: Select your VPC
  - Edit Routes → Add Route:
    - Destination: 0.0.0.0/0
    - Target: Select your NAT Gateway
  - Save changes
  - Subnet Associations → Edit → Select both private subnets.

## Create Security Groups
**Public Instance SG:(For Nginx Instance)**
  1. Name:  Public-Instance-SG
  2. Inbound Rules:
    - Allow SSH (port 22) from your IP
    - Allow HTTP (port 80) from anywhere
    - Allow custom TCP (ports 8080-8081) from anywhere(0.0.0.0/0)
  3. Outbound Rules: Allow All
**Private Instance SG:**
  1. Name: Private-Instance-SG
  2. Inbound Rules:
    - Allow HTTP (port 5000) from Public-Instance-SG
    - Allow SSH (port 22) from Public-Instance-SG
  3. Outbound Rules: Allow All

## Launch EC2 Instances
1. Public Instance:
  - AMI: Amazon Linux 2
  - Instance type: t2.micro
  - Network: Select your VPC
  - Subnet: ZustPe-Public-Subnet
  - Auto-assign Public IP: Enable
  - Security Group: Public-Instance-SG
  - User Data:
```
#!/bin/bash
yum update -y
amazon-linux-extras install nginx1 -y
systemctl start nginx
systemctl enable nginx

# Install Python and Flask for testing
yum install python3 -y
pip3 install flask

```

2. Private Instance 1:
 - AMI: Amazon Linux 2
 - Instance type: t2.micro
 - Network: Select your VPC
 - Subnet: ZustPe-Private-Subnet-1
 - Security Group: Private-Instance-SG
 - User Data
```
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
```

3. Private Instance 2:
  - Same as Private Instance 1 but with different user data:
```
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
```

## Configure Nginx as Reverse Proxy

On the public instance:
1. SSH into the public instance
```
chmod 400 ZustPe-key.pem
ssh -i ZustPe-key.pem ec2-user@<public-ip>
```
2. Configure Nginx
```
sudo nano /etc/nginx/conf.d/reverse-proxy.conf
```
```
server {
    listen 8080;
    location / {
        proxy_pass http://<Private-Instance-1-Private-IP>:5000;
    }
}

server {
    listen 8081;
    location / {
        proxy_pass http://<Private-Instance-2-Private-IP>:5000;
    }
}
```
- Troubleshoot (Optional)
In Public Subnet Create a ZustPe-key.pem file and Paste .pem here

To SSH into private instances (via the public instance):
```
ssh -i ZustPe-key.pem ec2-user@<private-ip>
```

3. Test and restart Nginx:
```
sudo nginx -t
sudo systemctl restart nginx
```