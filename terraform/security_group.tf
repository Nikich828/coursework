# 1. Группа безопасности для внутреннего трафика
resource "yandex_vpc_security_group" "internal" {
  name        = "internal-security-group"
  network_id  = yandex_vpc_network.coursework.id
  description = "Разрешает весь трафик внутри VPC"

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/16"]  # Вся внутренняя сеть
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]  # Исходящий трафик везде
  }
}

# 2. Группа безопасности для bastion хоста
resource "yandex_vpc_security_group" "public-bastion" {
  name        = "bastion-security-group"
  network_id  = yandex_vpc_network.coursework.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]  # SSH со всего мира
    port           = 22
  }

  ingress {
    protocol       = "ICMP"  # Ping
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Группа безопасности для веб-серверов
resource "yandex_vpc_security_group" "web" {
  name        = "web-servers-security-group"
  network_id  = yandex_vpc_network.coursework.id

  ingress {
    protocol       = "TCP"
    security_group_id = yandex_vpc_security_group.public-load-balancer.id  # Только от балансировщика
    port           = 80  # HTTP
  }

  ingress {
    protocol       = "TCP"
    security_group_id = yandex_vpc_security_group.public-bastion.id  # Только от bastion
    port           = 22  # SSH
  }

  # Node Exporter для Prometheus
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["${var.vm_ips.prometheus}/32"]  # Только с Prometheus
    port           = 9100
  }
  # Nginx Log Exporter для Prometheus
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["${var.vm_ips.prometheus}/32"]
    port           = 4040
  }

  # ICMP внутри сети
  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Группа безопасности для Elasticsearch
resource "yandex_vpc_security_group" "elasticsearch" {
  name        = "elasticsearch-security-group"
  network_id  = yandex_vpc_network.coursework.id

  # Только от веб-серверов для логов
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["${var.vm_ips.web1}/32", "${var.vm_ips.web2}/32"]
    port           = 9200  # Elasticsearch API
  }

  # Только от Kibana
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["${var.vm_ips.kibana}/32"]
    port           = 9200
  }

  # SSH только от bastion
  ingress {
    protocol       = "TCP"
    security_group_id = yandex_vpc_security_group.public-bastion.id
    port           = 22
  }

  # ICMP внутри сети
  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Группа безопасности для Prometheus
resource "yandex_vpc_security_group" "prometheus" {
  name        = "prometheus-security-group"
  network_id  = yandex_vpc_network.coursework.id

  # Только от Grafana
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["${var.vm_ips.grafana}/32"]
    port           = 9090  # Prometheus web UI
  }

  # SSH только от bastion
  ingress {
    protocol       = "TCP"
    security_group_id = yandex_vpc_security_group.public-bastion.id
    port           = 22
  }

  # ICMP внутри сети
  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Группа безопасности для публичного доступа к Grafana
resource "yandex_vpc_security_group" "public-grafana" {
  name        = "grafana-security-group"
  network_id  = yandex_vpc_network.coursework.id

  # Grafana web UI для всех
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }

  # SSH только от bastion
  ingress {
    protocol       = "TCP"
    security_group_id = yandex_vpc_security_group.public-bastion.id
    port           = 22
  }

  # ICMP для всех
  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Группа безопасности для публичного доступа к Kibana
resource "yandex_vpc_security_group" "public-kibana" {
  name        = "kibana-security-group"
  network_id  = yandex_vpc_network.coursework.id

  # Kibana web UI для всех
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  # SSH только от bastion
  ingress {
    protocol       = "TCP"
    security_group_id = yandex_vpc_security_group.public-bastion.id
    port           = 22
  }

  # ICMP для всех
  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# 8. Группа безопасности для Application Load Balancer
resource "yandex_vpc_security_group" "public-load-balancer" {
  name        = "alb-security-group"
  network_id  = yandex_vpc_network.coursework.id

  # Health checks от Yandex Cloud
  ingress {
    protocol          = "ANY"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    predefined_target = "loadbalancer_healthchecks"  # Специальная группа для health checks
  }

  # HTTP для всех
  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  # ICMP для всех
  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}