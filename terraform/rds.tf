
variable "db_snapshot_identifier" {
  description = "Snapshot used to restore the MarketWatch database. Null creates a new empty database."
  type        = string
  default     = null
}

variable "skip_final_snapshot" {
  description = "Skip RDS's automatic final snapshot when deleting the instance. Use only when a separate backup already exists."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Fallback final snapshot name for direct Terraform destroys."
  type        = string
  default     = "marketwatch-db-final-2"
}

resource "aws_db_subnet_group" "marketwatch" {
  name       = "marketwatch-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "marketwatch-db-subnet-group"
  }
}

resource "aws_security_group" "marketwatch_rds" {
  name        = "marketwatch-rds"
  description = "Security group for MarketWatch RDS"
  vpc_id      = module.vpc.vpc_id


  ingress {
    description = "PostgreSQL from MarketWatch API and collector"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"

    security_groups = [
      aws_security_group.marketwatch_api.id,
      aws_security_group.marketwatch_collector.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "marketwatch-rds"
  }
}

resource "aws_db_instance" "marketwatch" {
  identifier = "marketwatch-db"

  snapshot_identifier = var.db_snapshot_identifier

  engine         = "postgres"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "marketwatch"
  username = "marketwatch"

  manage_master_user_password   = true
  master_user_secret_kms_key_id = "alias/aws/secretsmanager"

  db_subnet_group_name   = aws_db_subnet_group.marketwatch.name
  vpc_security_group_ids = [aws_security_group.marketwatch_rds.id]

  publicly_accessible = false
  multi_az            = false
  storage_encrypted   = true

  skip_final_snapshot       = var.skip_final_snapshot
  deletion_protection       = false
  final_snapshot_identifier = var.final_snapshot_identifier

  backup_retention_period = 1

  tags = {
    Name = "marketwatch-db"
  }
}