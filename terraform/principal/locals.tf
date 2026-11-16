locals {
  name = "statline"

  tags = {
    Project   = "statline"
    Owner     = var.owner
    ManagedBy = "terraform"
    Stack     = "principal"
  }
}
