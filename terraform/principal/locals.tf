locals {
  name          = "statline"
  db_identifier = "${local.name}-pg"

  tags = {
    Project   = "statline"
    Owner     = var.owner
    ManagedBy = "terraform"
    Stack     = "principal"
  }
}
