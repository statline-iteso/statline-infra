# datos: RDS PostgreSQL 16 (db.t3.micro) in the private subnets, reachable only from the cluster
# security group. RDS creates no application databases: statline_staging and statline_prod are
# created by a one-off Job in the cluster (module plataforma), because the server is private (D-16).

resource "random_password" "admin" {
  length = 32
  # RDS rejects / @ " and spaces in the master password.
  special          = true
  override_special = "-_"
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-db"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "PostgreSQL from the EKS cluster security group only"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_cluster" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = var.cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS nodes and pods"
}

resource "aws_db_instance" "main" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = "16" # latest 16.x; minor upgrades are automatic
  instance_class = var.instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  username = var.admin_login
  password = random_password.admin.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  # make destroy runs after every session: no final snapshot (it would keep billing) and no
  # deletion protection. Dump before destroying (RUNBOOK §8).
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  # rds.force_ssl is on by default in PostgreSQL 16: DATABASE_URL uses sslmode=require.
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = false
  monitoring_interval             = 0 # enhanced monitoring needs its own IAM role
  auto_minor_version_upgrade      = true
}
