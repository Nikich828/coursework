# Виртуальная машина для Elasticsearch
resource "yandex_compute_instance" "elastic_vm" {
  name        = "elasticsearch-server"
  zone        = "ru-central1-b"
  platform_id = "standard-v3"
  allow_stopping_for_update = true

  # Больше памяти для Elasticsearch
  resources {
    cores  = 2
    memory = 8 
    core_fraction = 20
  }
  
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 20
    }
  }

  scheduling_policy {
    preemptible = true
  }
  
  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id  # Приватная подсеть
    nat                = false  # Без внешнего доступа
    security_group_ids = [
      yandex_vpc_security_group.elasticsearch.id, 
      yandex_vpc_security_group.internal.id
    ]
    ip_address         = var.vm_ips.elastic  # Статический IP
  }
  
  metadata = {
    user-data = file("./meta.yml")
  }
}