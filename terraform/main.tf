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

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  key_name = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_ssh_http_https.id]
  
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y nginx
              sudo apt install -y git

              # Create index.html with H1 tag in the default NGINX web directory
              echo "<h1>Hello From Ubuntu EC2 Instance!!!</h1>" | sudo tee /var/www/html/index.html

              # Update NGINX to listen on port 8080
              sudo sed -i 's/listen 80 default_server;/listen 8080 default_server;/g' /etc/nginx/sites-available/default

              # Restart NGINX to apply the changes
              sudo systemctl restart nginx

              # download the repo
              cd /home/ubuntu
              git clone git@github.com:jamby1100/terraform-workshop.git
  EOF
              
  tags = {
    Name = "HelloWorld"
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "./.ssh/terraform_rsa"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "./.ssh/terraform_rsa.pub"
}

resource "aws_key_pair" "deployer" {
  key_name   = "ubuntu_ssh_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_security_group" "allow_ssh_http_https" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 8080
    to_port     = 8080
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