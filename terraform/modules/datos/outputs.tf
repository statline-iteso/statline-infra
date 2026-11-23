output "address" {
  description = "Private DNS name of the instance."
  value       = aws_db_instance.main.address
}

output "database_names" {
  description = "Application databases (created by the plataforma Job)."
  value       = var.bases_de_datos
}

output "admin_url" {
  description = "Master connection string to the default postgres database (the plataforma Job creates the app databases with it)."
  value = format("postgresql://%s:%s@%s:5432/postgres?sslmode=require",
  urlencode(var.admin_login), urlencode(random_password.admin.result), aws_db_instance.main.address)
  sensitive = true
}

output "database_urls" {
  description = "DATABASE_URL per environment (key = env), with the master login and sslmode=require. Stored in SSM by module seguridad."
  value = {
    for db in var.bases_de_datos :
    trimprefix(db, "statline_") => format("postgresql://%s:%s@%s:5432/%s?sslmode=require",
    urlencode(var.admin_login), urlencode(random_password.admin.result), aws_db_instance.main.address, db)
  }
  sensitive = true
}
