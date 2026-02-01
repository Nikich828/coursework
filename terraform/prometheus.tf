# Виртуальная машина для Prometheus
resource "yandex_compute_instance" "prometheus_vm" {
  name        = "prometheus-server"
  zone        = "ru-central1-b"
  allow_stopping_for_update = true
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 4
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
    subnet_id = yandex_vpc_subnet.private.id  # Приватная подсеть
    nat       = false  # Без внешнего доступа
    
    security_group_ids = [
      yandex_vpc_security_group.prometheus.id, 
      yandex_vpc_security_group.internal.id
    ]
    ip_address         = var.vm_ips.prometheus  # Статический IP
  }

  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}