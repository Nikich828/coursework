# Группа бэкендов для балансировщика
resource "yandex_alb_backend_group" "my_backend_group" {
  name = "my-backend-group"

  # HTTP бэкенд
  http_backend {
    name             = "http-backend"
    weight           = 1  # Вес для балансировки
    port             = 80  # Порт веб-серверов
    target_group_ids = [yandex_alb_target_group.target-group.id]  # Целевая группа

    # Настройки балансировки
    load_balancing_config {
      panic_threshold = 90  # Порог паники
    }

    # Health check
    healthcheck {
      timeout  = "10s"
      interval = "2s"
      healthy_threshold = 10
      unhealthy_threshold = 15
      http_healthcheck {
        path = "/"  # Проверка по корневому пути
      }
    }
  }
}