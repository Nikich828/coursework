# Целевая группа для Application Load Balancer
resource "yandex_alb_target_group" "target-group" {
  name        = "web-target-group"

  # Веб-сервер 1
  target {
    subnet_id  = yandex_vpc_subnet.subnet_web-1.id
    ip_address = yandex_compute_instance.web-1.network_interface.0.ip_address
  }

  # Веб-сервер 2
  target {
    subnet_id  = yandex_vpc_subnet.subnet_web-2.id
    ip_address = yandex_compute_instance.web-2.network_interface.0.ip_address
  }
}