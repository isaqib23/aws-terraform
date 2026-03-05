# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet"
  }
}

# RDS Instance — restore from snapshot OR create fresh
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-rds"

  # If restoring from snapshot (cross-region copy)
  snapshot_identifier = var.snapshot_identifier != "" ? var.snapshot_identifier : null

  # Only needed when NOT restoring from snapshot
  engine         = var.snapshot_identifier == "" ? "postgres" : null
  engine_version = var.snapshot_identifier == "" ? "15.4" : null
  username       = var.snapshot_identifier == "" ? var.master_username : null
  password       = var.master_password

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2 # auto-scaling up to 2x
  storage_type          = "gp3"                     # cheaper than gp2
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  # NOT publicly accessible — only EKS nodes and bastion via SG
  publicly_accessible = false

  multi_az            = false # staging — single AZ to save cost
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Performance Insights (free tier)
  performance_insights_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}
