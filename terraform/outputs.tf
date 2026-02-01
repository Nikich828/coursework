# Вывод важной информации после деплоя

# Bastion хост
output "bastion_external_ip" {
  value       = yandex_compute_instance.bastion.network_interface.0.nat_ip_address  # Внешний IP для SSH
}

output "bastion_internal_ip" {
  value       = yandex_compute_instance.bastion.network_interface.0.ip_address  # Внутренний IP
}

output "bastion_fqdn" {
  value       = yandex_compute_instance.bastion.fqdn  # Полное доменное имя
}

# Grafana
output "grafana_external_ip" {
  value       = yandex_compute_instance.grafana_vm.network_interface.0.nat_ip_address  # Внешний IP для доступа
}

output "grafana_internal_ip" {
  value       = yandex_compute_instance.grafana_vm.network_interface.0.ip_address
}

output "grafana_fqdn" {
  value       = yandex_compute_instance.grafana_vm.fqdn
}

# Prometheus
output "prometheus_internal_ip" {
  value       = yandex_compute_instance.prometheus_vm.network_interface.0.ip_address  # Только внутренний
}

output "prometheus_fqdn" {
  value       = yandex_compute_instance.prometheus_vm.fqdn
}

# Kibana
output "kibana_external_ip" {
  value       = yandex_compute_instance.kibana_vm.network_interface.0.nat_ip_address
}

output "kibana_internal_ip" {
  value       = yandex_compute_instance.kibana_vm.network_interface.0.ip_address
}

output "kibana_fqdn" {
  value       = yandex_compute_instance.kibana_vm.fqdn
}

# Elasticsearch
output "elasticsearch_internal_ip" {
  value       = yandex_compute_instance.elastic_vm.network_interface.0.ip_address  # Только внутренний
}

output "elasticsearch_fqdn" {
  value       = yandex_compute_instance.elastic_vm.fqdn
}

# Веб-серверы
output "web1_internal_ip" {
  value       = yandex_compute_instance.web-1.network_interface.0.ip_address
}

output "web1_fqdn" {
  value       = yandex_compute_instance.web-1.fqdn
}

output "web2_internal_ip" {
  value       = yandex_compute_instance.web-2.network_interface.0.ip_address
}

output "web2_fqdn" {
  value       = yandex_compute_instance.web-2.fqdn
}

# Load Balancer
output "alb_external_ip" {
  value       = yandex_alb_load_balancer.my_alb.listener.0.endpoint.0.address.0.external_ipv4_address.0.address  # Внешний IP балансировщика
}