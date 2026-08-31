variable "FORGEJO_DB_PASSWD" {
  type      = string
  sensitive = true
}

variable "MONGO_URI" {
  type      = string
  sensitive = true
}

variable "JWT_SECRET" {
  type      = string
  sensitive = true
}

variable "JWT_REFRESH_SECRET" {
  type      = string
  sensitive = true
}

variable "CREDS_KEY" {
  type      = string
  sensitive = true
}

variable "CREDS_IV" {
  type      = string
  sensitive = true
}

variable "SONARR_DB_PASSWORD" {
  type      = string
  sensitive = true
}

variable "RADARR_DB_PASSWORD" {
  type      = string
  sensitive = true
}

variable "LIDARR_DB_PASSWORD" {
  type      = string
  sensitive = true
}

variable "MYSQL_ROOT_PASSWORD" {
  type      = string
  sensitive = true
}

variable "APP_MYSQL_PASSWORD" {
  type      = string
  sensitive = true
}

variable "MONGO_INITDB_ROOT_USERNAME" {
  type      = string
  sensitive = true
}

variable "MONGO_INITDB_ROOT_PASSWORD" {
  type      = string
  sensitive = true
}

variable "DB_POSTGRESDB_PASSWORD" {
  type      = string
  sensitive = true
}

variable "N8N_ENCRYPTION_KEY" {
  type      = string
  sensitive = true
}

variable "PAPERLESS_SECRET_KEY" {
  type      = string
  sensitive = true
}

variable "PAPERLESS_DBPASS" {
  type      = string
  sensitive = true
}

variable "PAPERLESS_REDIS_PASSWORD" {
  type      = string
  sensitive = true
}

variable "PGADMIN_DEFAULT_EMAIL" {
  type      = string
  sensitive = true
}

variable "PGADMIN_DEFAULT_PASSWORD" {
  type      = string
  sensitive = true
}

variable "FTLCONF_webserver_api_password" {
  type      = string
  sensitive = true
}

variable "POSTGRES_PASSWORD" {
  type      = string
  sensitive = true
}

variable "REDIS_PASSWORD" {
  type      = string
  sensitive = true
}

variable "VIKUNJA_DATABASE_PASSWORD" {
  type      = string
  sensitive = true
}

variable "VIKUNJA_SERVICE_SECRET" {
  type      = string
  sensitive = true
}
