# Конфигурация провайдера и основные ресурсы
terraform {
  required_version = "= 1.9.2"  # Фиксированная версия
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "= 0.129.0"  # Фиксированная версия провайдера
    }
  }
}

# Провайдер Yandex Cloud
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  service_account_key_file = file("~/Downloads/.authorized_key.json")  # Ключ сервисного аккаунта
  zone      = "ru-central1-a"
}

# Получение образа Ubuntu
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"  # Семейство образов
}

# Веб-сервер 1
resource "yandex_compute_instance" "web-1" {
  name         = "web-server-1"
  zone         = "ru-central1-a"
  platform_id  = "standard-v3"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  scheduling_policy {
    preemptible = true  # Прерываемая ВМ
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_web-1.id
    nat       = false  # Без внешнего IP
    
    security_group_ids = [
      yandex_vpc_security_group.web.id,
      yandex_vpc_security_group.internal.id
    ]
    ip_address = var.vm_ips.web1  # Статический IP
  }

  metadata = {
    user-data = "${file("./meta.yml")}"  # Cloud-init
  }
}

# Веб-сервер 2 (в другой зоне)
resource "yandex_compute_instance" "web-2" {
  name         = "web-server-2"
  zone         = "ru-central1-b"  # Другая зона для отказоустойчивости
  platform_id  = "standard-v3"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_web-2.id
    nat       = false 
    
    security_group_ids = [
      yandex_vpc_security_group.web.id,
      yandex_vpc_security_group.internal.id
    ]
    ip_address = var.vm_ips.web2  # Статический IP
  }

  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

# Генерация inventory файла для Ansible
resource "local_file" "inventory" {
  content  = <<-EOT
[bastion]
${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=nvlychagin ansible_ssh_private_key_file=~/.ssh/id_ed25519

[webservers]
${yandex_compute_instance.web-1.name} ansible_host=${yandex_compute_instance.web-1.network_interface.0.ip_address} ansible_user=nvlychagin
${yandex_compute_instance.web-2.name} ansible_host=${yandex_compute_instance.web-2.network_interface.0.ip_address} ansible_user=nvlychagin
  
[webservers:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q nvlychagin@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'  # SSH через bastion
ansible_ssh_private_key_file=~/.ssh/id_ed25519
elasticsearch_host=${yandex_compute_instance.elastic_vm.network_interface.0.ip_address}
kibana_host=${yandex_compute_instance.kibana_vm.network_interface.0.ip_address}

[elastic]
${yandex_compute_instance.elastic_vm.name} ansible_host=${yandex_compute_instance.elastic_vm.network_interface.0.ip_address} ansible_user=nvlychagin
  
[elastic:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q nvlychagin@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
ansible_ssh_private_key_file=~/.ssh/id_ed25519

[kibana]
${yandex_compute_instance.kibana_vm.name} ansible_host=${yandex_compute_instance.kibana_vm.network_interface.0.ip_address} ansible_user=nvlychagin
  
[kibana:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q nvlychagin@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
ansible_ssh_private_key_file=~/.ssh/id_ed25519
elasticsearch_host=${yandex_compute_instance.elastic_vm.network_interface.0.ip_address}

[grafana]
${yandex_compute_instance.grafana_vm.name} ansible_host=${yandex_compute_instance.grafana_vm.network_interface.0.ip_address} ansible_user=nvlychagin
  
[grafana:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q nvlychagin@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
ansible_ssh_private_key_file=~/.ssh/id_ed25519

[prometheus]
${yandex_compute_instance.prometheus_vm.name} ansible_host=${yandex_compute_instance.prometheus_vm.network_interface.0.ip_address} ansible_user=nvlychagin
  
[prometheus:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q nvlychagin@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
ansible_ssh_private_key_file=~/.ssh/id_ed25519

[all_private:children]
webservers
elastic
prometheus

[all_private:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q nvlychagin@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
ansible_ssh_private_key_file=~/.ssh/id_ed25519

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q nvlychagin@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  EOT
  
  filename = "../ansible/inventory.ini"  # Путь к файлу
  
  depends_on = [  # Зависимости от всех ВМ
    yandex_compute_instance.bastion,
    yandex_compute_instance.web-1,
    yandex_compute_instance.web-2,
    yandex_compute_instance.elastic_vm,
    yandex_compute_instance.kibana_vm,
    yandex_compute_instance.grafana_vm,
    yandex_compute_instance.prometheus_vm
  ]
}

# Генерация переменных для Ansible
resource "local_file" "ansible_vars" {
  content = <<-EOT
  elasticsearch_host: "${var.vm_ips.elastic}"
  prometheus_host: "${var.vm_ips.prometheus}"
  kibana_host: "${yandex_compute_instance.kibana_vm.network_interface.0.ip_address}"
  grafana_host: "${yandex_compute_instance.grafana_vm.network_interface.0.ip_address}"
  
  # Версии компонентов
  elasticsearch_version: "8.8.0"
  kibana_version: "8.8.0"
  filebeat_version: "8.8.0"
  prometheus_version: "2.51.2"
  node_exporter_version: "1.7.0"
  nginx_log_exporter_version: "1.9.0"
  grafana_version: "12.3.1"
  
  website_local_path: "${var.website_files_path}"
  website_remote_path: "/var/www/html"
  EOT
  
  filename = "../ansible/group_vars/all.yml"  # Переменные для всех групп
}