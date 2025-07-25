# Retrieve latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Make sure that it's official by checking the owner
  owners = ["099720109477"] # Canonical
}

# Create an EC2 Instance with the Ubuntu AMI from the previous block
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  key_name = aws_key_pair.deployer.key_name
  associate_public_ip_address = true  
  vpc_security_group_ids = [aws_security_group.allow_ssh_http_https.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y python3 python3-pip git nginx

              # Clone your repo
              git clone https://github.com/MachiBytes/terraform-workshop.git /home/ubuntu/app
              cd /home/ubuntu/app/flask_app

              # Install Python dependencies
              pip3 install --upgrade pip
              pip3 install -r requirements.txt

              # Start the Flask app using nohup (assumes app.py runs on 0.0.0.0:5000)
              nohup python3 app.py > app.log 2>&1 &

              # Configure NGINX to proxy traffic to the Flask app
              tee /etc/nginx/sites-available/default > /dev/null << EOL
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;

                  location / {
                      proxy_pass http://127.0.0.1:5000;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto \$scheme;
                  }
              }
              EOL

              # Restart NGINX
              systemctl restart nginx
  EOF
              
  tags = {
    Name = "HelloWorld"
  }
}


# This creates a secure ssh key for connecting to the instance with SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Setups the private key inside the Cloud9 environment
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "./.ssh/terraform_rsa"
}

# Setups the public key inside the Cloud9 environment
resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "./.ssh/terraform_rsa.pub"
}

# Creates a key pair in AWS
resource "aws_key_pair" "deployer" {
  key_name   = "markflores_terraform_ubuntu_ssh_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}


# Creates a security group that allows ssh and http
resource "aws_security_group" "allow_ssh_http_https" {
  # Allow SSH inbound traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP inbound traffic
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

  tags = {
    Name = "allow-ssh-http"
  }
}

# Creates dynamodb table named products-072025
resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "products-072025"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key       = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }


  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name        = "products-072025"
    Environment = "production"
  }
}

# Allow EC2 instance to assume role
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create the actual IAM role that the EC2 instance will assume
# Initialized with the ec2_assume_role_policy
resource "aws_iam_role" "ec2_role" {
  name               = "terraform-ec2-dynamodb-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

# Creates another policy that allows PutItem and Scan actions only to the dynamodb table we created
data "aws_iam_policy_document" "dynamodb_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:Scan"
    ]
    resources = [
      aws_dynamodb_table.basic-dynamodb-table.arn
    ]
  }
}

# Adds the previous policy document that we created to the IAM role we created
resource "aws_iam_role_policy" "dynamodb_access" {
  name   = "dynamodb-access"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.dynamodb_access_policy.json
}

# Creates an instance profile that we can use to add the role to our EC2 instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-helloworld-profile"
  role = aws_iam_role.ec2_role.name
}