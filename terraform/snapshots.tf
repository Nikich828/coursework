# Автоматическое резервное копирование ВМ
resource "yandex_compute_snapshot_schedule" "daily_backups" {
  name        = "daily-vm-backups"

  schedule_policy {
    expression = "0 1 * * *"  # Каждый день в 1:00
  }

  snapshot_count = 7  # Хранить 7 снимков

  snapshot_spec {
    description = "Daily backup"
  }

  # Диски всех ВМ для резервного копирования
  disk_ids = [
    yandex_compute_instance.bastion.boot_disk.0.disk_id,
    yandex_compute_instance.web-1.boot_disk.0.disk_id,
    yandex_compute_instance.web-2.boot_disk.0.disk_id,
    yandex_compute_instance.elastic_vm.boot_disk.0.disk_id,
    yandex_compute_instance.kibana_vm.boot_disk.0.disk_id,
    yandex_compute_instance.grafana_vm.boot_disk.0.disk_id,
    yandex_compute_instance.prometheus_vm.boot_disk.0.disk_id
  ]
}