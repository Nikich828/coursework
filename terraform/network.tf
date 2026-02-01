# Создание VPC сети
resource "yandex_vpc_network" "coursework" {
  name = "course-project-vpc"
}

# 1. Создание управляемого NAT Gateway
resource "yandex_vpc_gateway" "shared_egress_gw" {
  name = "shared-egress-gateway"
  shared_egress_gateway {}  # Управляемый NAT Gateway
}

# 2. Таблица маршрутов для приватных подсетей
resource "yandex_vpc_route_table" "private-subnets-to-nat" {
  name        = "nat-gateway-route-table"
  network_id  = yandex_vpc_network.coursework.id

  static_route {
    destination_prefix = "0.0.0.0/0"  # Весь трафик
    gateway_id         = yandex_vpc_gateway.shared_egress_gw.id  # Через NAT Gateway
  }
}

# 3. Приватные подсети
resource "yandex_vpc_subnet" "subnet_web-1" {
  name           = "private-subnet-web-1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.coursework.id
  v4_cidr_blocks = [var.network_cidr.web1]  # 10.0.1.0/24
  route_table_id = yandex_vpc_route_table.private-subnets-to-nat.id  # Привязка к таблице маршрутов
}

resource "yandex_vpc_subnet" "subnet_web-2" {
  name           = "private-subnet-web-2"
  zone           = "ru-central1-b"  # Другая зона
  network_id     = yandex_vpc_network.coursework.id
  v4_cidr_blocks = [var.network_cidr.web2]  # 10.0.2.0/24
  route_table_id = yandex_vpc_route_table.private-subnets-to-nat.id
}

resource "yandex_vpc_subnet" "private" {
  name           = "private-subnet-monitoring"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.coursework.id
  v4_cidr_blocks = [var.network_cidr.private]  # 10.0.3.0/24
  route_table_id = yandex_vpc_route_table.private-subnets-to-nat.id
}

# 4. Публичная подсеть
resource "yandex_vpc_subnet" "public" {
  name           = "public-subnet"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.coursework.id
  v4_cidr_blocks = [var.network_cidr.public]  # 10.0.4.0/24
  # Без route_table_id - использует маршрут по умолчанию с NAT
}