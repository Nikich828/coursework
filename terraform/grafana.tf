# Виртуальная машина для Grafana
resource "yandex_compute_instance" "grafana_vm" {
  name        = "grafana-server"
  zone        = "ru-central1-b"
  allow_stopping_for_update = true
  platform_id = "standard-v3"

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
    subnet_id = yandex_vpc_subnet.public.id  # Публичная подсеть
    nat       = true  # С внешним доступом
    
    security_group_ids = [
      yandex_vpc_security_group.internal.id, 
      yandex_vpc_security_group.public-grafana.id
    ]
    ip_address         = var.vm_ips.grafana  # Статический IP
  }

  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}