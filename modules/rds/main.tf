data "aws_subnet_ids" "subnets" {
  vpc_id = var.vpc_id
}

resource "aws_db_subnet_group" "rdsDbSubnetGp" {
  name       = "rdssubnetgp"
  subnet_ids = data.aws_subnet_ids.subnets.ids
}

resource "aws_db_parameter_group" "rdsDbParamGp" {
  name        = "postgres-parameters"
  family      = "postgres12"
  description = "Postgres parameter group"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "rdsDbInstance" {
  identifier             = var.rds_identifier
  instance_class         = "db.t3.micro"
  skip_final_snapshot = true
  storage_type              = "gp2"
  allocated_storage = 20
  max_allocated_storage = 0
  multi_az = false
  name                      = "csye6225"
  engine                 = "postgres"
  engine_version         = "12.8"
  username               = var.username
  password               = var.password
  db_subnet_group_name   = aws_db_subnet_group.rdsDbSubnetGp.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.rdsDbParamGp.name
  publicly_accessible    = false
}