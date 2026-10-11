resource "aws_security_group" "marketwatch_api" {
  name        = "marketwatch-api"
  description = "Allow traffic to the Market Watch API"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Market Watch API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "marketwatch_collector" {
  name        = "marketwatch-collector"
  description = "Outbound access for the MarketWatch price collector"
  vpc_id      = module.vpc.vpc_id

  # No inbound rules required.
  # The collector initiates all connections.
  egress {
    description = "Outbound HTTPS, database, and service access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "marketwatch-collector"
    Project = "MarketWatch"
  }
}