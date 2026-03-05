# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet"
  }
}

# Enhanced Monitoring IAM Role (match prod)
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Instance — restore from snapshot OR create fresh
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-rds"

  # If restoring from snapshot (cross-region copy)
  snapshot_identifier = var.snapshot_identifier != "" ? var.snapshot_identifier : null

  # Only needed when NOT restoring from snapshot
  engine         = var.snapshot_identifier == "" ? "postgres" : null
  engine_version = var.snapshot_identifier == "" ? "16.6" : null
  username       = var.snapshot_identifier == "" ? var.master_username : null
  password       = var.master_password

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  publicly_accessible = false

  multi_az            = var.multi_az
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:04:30"

  # Enhanced monitoring (match prod: 60s interval)
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Performance Insights
  performance_insights_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}
