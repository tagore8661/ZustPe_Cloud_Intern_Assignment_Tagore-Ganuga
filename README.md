# Cloud Engineer Intern - Assignment

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed
3. SSH key pair (will be generated automatically)

### AWS Credentials Setup

***Option 1***: **AWS CLI Configure**
```bash
aws configure
```

***Option 2***: **Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

***Option 3***: **AWS Profile**
```bash
export AWS_PROFILE="your-profile-name"
```

### Verify AWS Access
```bash
aws sts get-caller-identity
```
## Quick Start

### Step 1: Clone Repository
```bash
git clone <repository-url>
cd <repository-name>
```

### Step 2: Deploy Infrastructure

***Option 1***: Manually Infra

See ***Cloud-Manual-Setup.md*** in this repository, for step-by-step Manual infra Creation using AWS Console.

***Option 2***: Terraform Infra
```powershell
cd .\terraform
terraform init
terraform plan 
terraform apply --auto-approve
```

After applying, Terraform will output:
- Public IP of the public instance
- Private IPs of the private instances
- Path to the generated SSH private key

## Accessing the Application

1. Access Private Instance 1:
```
http://<public-ip>:8080
```
***Should display***: "Hello I am from Private-1 Instance"

2. Access Private Instance 2:
```
http://<public-ip>:8081
```
***Should display***: "Hello I am from Private-2 Instance"

## Troubleshoot (Optional)

To SSH into the public instance:
```
chmod 400 ZustPe-key.pem
ssh -i ZustPe-key.pem ec2-user@<public-ip>
```
In Public Subnet Create a ZustPe-key.pem file and Paste .pem here

To SSH into private instances (via the public instance):
```
ssh -i ZustPe-key.pem ec2-user@<private-ip>
```
## Cleanup
To destroy all created resources:

```
terraform destroy --auto-approve
```