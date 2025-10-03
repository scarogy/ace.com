locals {
  create = var.enabled
}

resource "aws_db_subnet_group" "this" {
  count      = local.create ? 1 : 0
  name       = "${var.name}-db"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  count  = local.create ? 1 : 0
  name   = "${var.name}-db"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-db" }
}
locals {
  ingress_sg_map = {
    for idx, sg in var.ingress_security_group_ids :
    tostring(idx) => sg
  }
}

resource "aws_security_group_rule" "ingress_from_sg" {
  for_each                 = local.ingress_sg_map
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db[0].id
  source_security_group_id = each.value
  depends_on               = [aws_security_group.db]
}



resource "random_password" "db" {
  count   = local.create ? 1 : 0
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.name}/db/credentials"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    engine   = "postgres"
    username = "appuser"
    password = random_password.db[0].result
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "this" {
  count                  = local.create ? 1 : 0
  identifier             = "${var.name}-pg"
  engine                 = "postgres"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  storage_type           = "gp3"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  vpc_security_group_ids = [aws_security_group.db[0].id]

  username = "appuser"
  password = random_password.db[0].result
  db_name  = var.db_name

  backup_retention_period = var.backup_retention
  deletion_protection     = var.deletion_protection
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = false
}
