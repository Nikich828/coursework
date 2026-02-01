# Основные переменные конфигурации

# Идентификаторы Yandex Cloud
variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  default     = "b1gsv0iedv4orkas8lug"  # Пример cloud_id
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
  default     = "b1gjbqa87bvhrtjk7g6e"  # Пример folder_id
}

# CIDR блоки для сети
variable "network_cidr" {
  description = "Network CIDR blocks"
  type = map(string)
  default = {
    web1     = "10.0.1.0/24"  # Веб-сервер 1
    web2     = "10.0.2.0/24"  # Веб-сервер 2
    private  = "10.0.3.0/24"  # Приватная подсеть для мониторинга
    public   = "10.0.4.0/24"  # Публичная подсеть
  }
}

# Статические IP адреса для ВМ
variable "vm_ips" {
  description = "Static IP addresses for VMs"
  type = map(string)
  default = {
    web1      = "10.0.1.22"
    web2      = "10.0.2.19"
    elastic   = "10.0.3.15"
    prometheus = "10.0.3.11"
    bastion   = "10.0.4.5"
    kibana    = "10.0.4.13"
    grafana   = "10.0.4.19"
  }
}

# Локальный путь к файлам сайта
variable "website_files_path" {
  description = "Local path to website files"
  type        = string
  default     = "../website"  # Относительный путь
}