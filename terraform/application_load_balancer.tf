# Создание Application Load Balancer в Yandex Cloud
resource "yandex_alb_load_balancer" "my_alb" {
  name        = "my-alb"
  network_id  = yandex_vpc_network.coursework.id  # Сеть VPC
  security_group_ids = [yandex_vpc_security_group.public-load-balancer.id, yandex_vpc_security_group.internal.id]  # Группы безопасности

  # Политика размещения
  allocation_policy {
    location {
      zone_id = "ru-central1-b"  # Зона доступности
      subnet_id = yandex_vpc_subnet.public.id  # Публичная подсеть
    }
  }

  # HTTP listener
  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {}  # Автоматический внешний IP
      }
      ports = [80]  # Порт 80
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.my_router.id  # Маршрутизатор
      }
    }
  }
}