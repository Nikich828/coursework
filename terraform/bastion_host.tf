# Bastion хост для доступа к приватным серверам
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"
  allow_stopping_for_update = true  # Разрешить остановку для обновления

  # Ресурсы ВМ
  resources {
    cores  = 2
    memory = 2
    core_fraction = 20  # Гарантированная доля vCPU
  }

  # Системный диск
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id  # Ubuntu 22.04
      type     = "network-hdd"
      size     = 10
    }
  }

  # Прерываемая ВМ для экономии
  scheduling_policy {
    preemptible = true
  }
  
  # Сетевой интерфейс
  network_interface {
    subnet_id      = yandex_vpc_subnet.public.id  # Публичная подсеть
    nat            = true  # NAT для внешнего доступа
    security_group_ids = [
      yandex_vpc_security_group.internal.id, 
      yandex_vpc_security_group.public-bastion.id
    ]
    ip_address = var.vm_ips.bastion  # Статический IP
  }

  # Cloud-init конфигурация
  metadata = {
    user-data = "${file("./meta.yml")}"  # Файл инициализации
  }
}