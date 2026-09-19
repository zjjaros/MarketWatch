data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "marketwatch_api" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.marketwatch_api.id]
  associate_public_ip_address = true

  key_name = "marketwatch-ec2"

  user_data = <<-EOF
    #!/bin/bash

    apt update
    apt install -y docker.io docker-compose-v2

    systemctl enable docker
    systemctl start docker
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "marketwatch-api"
  }
}