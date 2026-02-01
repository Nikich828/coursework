# HTTP роутер для Application Load Balancer
resource "yandex_alb_http_router" "my_router" {
  name        = "web-http-router"
}

# Виртуальный хост
resource "yandex_alb_virtual_host" "my_virtual_host" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.my_router.id

  route {
    name = "web-route"
    http_route {
      http_match {
        path {
          prefix = "/"  # Все пути
        }
      }

      http_route_action {
        backend_group_id = yandex_alb_backend_group.my_backend_group.id  # Группа бэкендов
      }
    }
  }
}