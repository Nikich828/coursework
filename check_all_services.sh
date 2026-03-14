#!/bin/bash
echo "=== ПОЛНАЯ ПРОВЕРКА ИНФРАСТРУКТУРЫ ==="
echo

echo "1. ВЕБ-СЕРВЕРЫ:"
echo "--------------"
echo "Nginx:"
ansible webservers -i inventory.ini -b -m shell -a "systemctl is-active nginx" 2>/dev/null | grep -v CHANGED
echo
echo "Node Exporter (порт 9100):"
ansible webservers -i inventory.ini -b -m shell -a "ss -tlnp | grep :9100 | head -1" 2>/dev/null
echo
echo "Nginx Log Exporter (порт 4040):"
ansible webservers -i inventory.ini -b -m shell -a "ss -tlnp | grep :4040 | head -1" 2>/dev/null

echo
echo "2. PROMETHEUS:"
echo "-------------"
echo "Статус службы:"
ansible prometheus -i inventory.ini -b -m shell -a "systemctl is-active prometheus" 2>/dev/null | grep -v CHANGED
echo
echo "Targets в Prometheus (должно быть 4 UP):"

# Получаем количество UP targets
TARGETS_COUNT=$(ansible prometheus -i inventory.ini -b -m shell -a "curl -s 'http://localhost:9090/api/v1/targets' | grep -o '\"health\":\"up\"' | wc -l" 2>/dev/null)
# Извлекаем только число из вывода
TARGETS_COUNT=$(echo "$TARGETS_COUNT" | grep -E '^[0-9]+$' | tail -1)

if [ -z "$TARGETS_COUNT" ]; then
    TARGETS_COUNT=0
fi

echo "  UP: $TARGETS_COUNT/4"

# Показываем детали
ansible prometheus -i inventory.ini -b -m shell -a "curl -s 'http://localhost:9090/api/v1/targets' | grep -o '\"scrapeUrl\":\"[^\"]*\"\|\"health\":\"[^\"]*\"' | sed 's/\"scrapeUrl\":\"/  Target: /g' | sed 's/\"health\":\"/ - Health: /g' | sed 's/\"$//g' | paste - -" 2>/dev/null | grep -v CHANGED

echo
echo "3. GRAFANA:"
echo "----------"
echo "Статус службы:"
ansible grafana -i inventory.ini -b -m shell -a "systemctl is-active grafana-server" 2>/dev/null | grep -v CHANGED
echo
echo "Проверка API:"
GRAFANA_STATUS=$(ansible grafana -i inventory.ini -b -m shell -a "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api/health" 2>/dev/null | tail -1 | tr -d '[:space:]')
if [ "$GRAFANA_STATUS" = "200" ]; then
    echo "  ✓ Grafana API доступен (HTTP $GRAFANA_STATUS)"
    
    echo
    echo "Проверка datasources:"
    DS_CHECK=$(ansible grafana -i inventory.ini -b -m shell -a "curl -s -u admin:admin123 'http://localhost:3000/api/datasources' | grep -o 'Prometheus'" 2>/dev/null | tail -1 | tr -d '[:space:]')
    if [ "$DS_CHECK" = "Prometheus" ]; then
        echo "  ✓ Prometheus datasource настроен"
    else
        echo "  ✗ Prometheus datasource не найден"
    fi
    
    echo
    echo "Проверка дашбордов:"
    DASH_COUNT=$(ansible grafana -i inventory.ini -b -m shell -a "curl -s -u admin:admin123 'http://localhost:3000/api/search' | grep -o '\"title\":' | wc -l" 2>/dev/null | tail -1 | tr -d '[:space:]')
    if [ -n "$DASH_COUNT" ] && [ "$DASH_COUNT" -gt 0 ]; then
        echo "  ✓ Найдено дашбордов: $DASH_COUNT"
        echo
        echo "Список дашбордов:"
        ansible grafana -i inventory.ini -b -m shell -a "curl -s -u admin:admin123 'http://localhost:3000/api/search' | grep -o '\"title\":\"[^\"]*\"' | sed 's/\"title\":\"//g' | sed 's/\"//g'" 2>/dev/null | grep -v CHANGED | sed 's/^/    - /'
    else
        echo "  ✗ Дашборды не найдены"
    fi
else
    echo "  ✗ Grafana недоступна (HTTP $GRAFANA_STATUS)"
fi

echo
echo "4. ELASTICSEARCH И KIBANA:"
echo "--------------------------"
echo "Elasticsearch:"
ES_STATUS=$(ansible elastic -i inventory.ini -b -m shell -a "curl -s 'http://localhost:9200/_cluster/health?pretty' | grep '\"status\"' | head -1 | cut -d'\"' -f4" 2>/dev/null | tail -1 | tr -d '[:space:]')
if [ -n "$ES_STATUS" ]; then
    echo "  Статус кластера: $ES_STATUS"
else
    echo "  ✗ Elasticsearch недоступен"
    ES_STATUS="недоступен"
fi

echo
echo "Kibana:"
# Проверяем через API с заголовком kbn-xsrf - это правильный способ
KIBANA_API_STATUS=$(ansible kibana -i inventory.ini -b -m shell -a "curl -s -H 'kbn-xsrf: true' -o /dev/null -w '%{http_code}' http://localhost:5601/api/status" 2>/dev/null | tail -1 | tr -d '[:space:]')
if [ "$KIBANA_API_STATUS" = "200" ]; then
    echo "  ✓ Kibana API доступен (HTTP $KIBANA_API_STATUS)"
    
    # Дополнительно проверяем веб-интерфейс через редирект
    KIBANA_WEB_STATUS=$(ansible kibana -i inventory.ini -b -m shell -a "curl -s -L -o /dev/null -w '%{http_code}' http://localhost:5601" 2>/dev/null | tail -1 | tr -d '[:space:]')
    if [ "$KIBANA_WEB_STATUS" = "200" ]; then
        echo "  ✓ Kibana Web доступен (HTTP $KIBANA_WEB_STATUS после редиректа)"
    else
        echo "  ⚠️ Kibana Web: HTTP $KIBANA_WEB_STATUS"
    fi
else
    echo "  ✗ Kibana API недоступен (HTTP $KIBANA_API_STATUS)"
fi

echo
echo "5. FILEBEAT И ЛОГИ:"
echo "------------------"
echo "Проверка Filebeat:"
FB_STATUS=$(ansible webservers -i inventory.ini -b -m shell -a "systemctl is-active filebeat" 2>/dev/null | grep -v CHANGED | head -1 | tr -d '[:space:]')
if [ "$FB_STATUS" = "active" ]; then
    echo "  ✓ Filebeat активен на веб-серверах"
    
    # Проверяем документы в Elasticsearch
    echo
    echo "Проверка логов в Elasticsearch:"
    DOC_COUNT=$(ansible elastic -i inventory.ini -b -m shell -a "curl -s 'http://localhost:9200/_cat/indices?v' | grep filebeat | awk '{print \$7}'" 2>/dev/null | tail -1 | tr -d '[:space:]')
    if [ -n "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
        echo "  ✓ Логов в Elasticsearch: $DOC_COUNT документов"
    else
        echo "  ✗ Логи не найдены в Elasticsearch"
    fi
else
    echo "  ✗ Filebeat не активен"
fi

echo
echo "6. ПРОВЕРКА МЕТРИК В PROMETHEUS:"
echo "-------------------------------"
echo "Доступность метрик через экспортеры:"

# Проверка Node Exporter
echo "Node Exporter метрики:"
NODE_CHECK=$(ansible webservers -i inventory.ini -b -m shell -a "curl -s -o /dev/null -w '%{http_code}' http://localhost:9100/metrics" 2>/dev/null | tail -1 | tr -d '[:space:]')
if [ "$NODE_CHECK" = "200" ]; then
    echo "  ✓ Node Exporter отвечает (HTTP 200)"
    NODE_METRICS_COUNT=$(ansible webservers -i inventory.ini -b -m shell -a "curl -s http://localhost:9100/metrics | grep -c '^[^#]'" 2>/dev/null | tail -1 | tr -d '[:space:]')
    echo "    Метрик доступно: ~$NODE_METRICS_COUNT"
else
    echo "  ✗ Node Exporter не отвечает"
fi

# Проверка Nginx Exporter
echo
echo "Nginx Exporter метрики:"
NGINX_CHECK=$(ansible webservers -i inventory.ini -b -m shell -a "curl -s -o /dev/null -w '%{http_code}' http://localhost:4040/metrics" 2>/dev/null | tail -1 | tr -d '[:space:]')
if [ "$NGINX_CHECK" = "200" ]; then
    echo "  ✓ Nginx Exporter отвечает (HTTP 200)"
    NGINX_METRICS=$(ansible webservers -i inventory.ini -b -m shell -a "curl -s http://localhost:4040/metrics | grep 'nginx_http_response_count_total'" 2>/dev/null | tail -1)
    if [ -n "$NGINX_METRICS" ]; then
        echo "    ✓ Метрика nginx_http_response_count_total доступна"
    else
        echo "    ✗ Метрика nginx_http_response_count_total не найдена"
    fi
else
    echo "  ✗ Nginx Exporter не отвечает"
fi

# Проверка в Prometheus
echo
echo "Проверка в Prometheus:"
PROM_METRICS_CHECK=$(ansible prometheus -i inventory.ini -b -m shell -a "curl -s 'http://localhost:9090/api/v1/label/__name__/values' | grep -c 'node_' | head -1" 2>/dev/null | tail -1 | tr -d '[:space:]')
if [ -n "$PROM_METRICS_CHECK" ] && [ "$PROM_METRICS_CHECK" -gt 0 ]; then
    echo "  ✓ Метрики Node доступны в Prometheus"
else
    echo "  ✗ Метрики Node не найдены в Prometheus"
fi

echo
echo "7. WEB-ИНТЕРФЕЙСЫ:"
echo "------------------"
echo "Grafana:     http://10.0.4.19:3000"
echo "  Логин: admin, Пароль: admin123"
echo
echo "Prometheus:  http://10.0.3.11:9090"
echo
echo "Kibana:      http://10.0.4.13:5601"
echo
echo "Веб-сервер 1: http://10.0.1.22"
echo "Веб-сервер 2: http://10.0.2.19"

echo
echo "8. БЫСТРАЯ ПРОВЕРКА РАБОТЫ:"
echo "---------------------------"
echo "Генерация тестового трафика на веб-серверы:"
for i in {1..3}; do
    echo "  Запрос $i..."
    ansible webservers -i inventory.ini -b -m shell -a "curl -s -o /dev/null -w '    %{http_code} - %{url_effective}\n' http://localhost" 2>/dev/null | grep -v CHANGED
    sleep 1
done

echo
echo "=== ИТОГ ПРОВЕРКИ ==="
echo

# Сводка результатов
ALL_SERVICES_ACTIVE=true
PROMETHEUS_TARGETS_OK=false
GRAFANA_OK=false
ELASTICSEARCH_OK=false
KIBANA_OK=false
LOGS_OK=false
NODE_EXPORTER_OK=false
NGINX_EXPORTER_OK=false

# Проверка всех сервисов
if [ "$TARGETS_COUNT" -eq 4 ]; then
    PROMETHEUS_TARGETS_OK=true
fi

if [ "$GRAFANA_STATUS" = "200" ]; then
    GRAFANA_OK=true
fi

if [ "$ES_STATUS" = "green" ] || [ "$ES_STATUS" = "yellow" ]; then
    ELASTICSEARCH_OK=true
fi

if [ "$KIBANA_API_STATUS" = "200" ]; then
    KIBANA_OK=true
fi

if [ -n "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
    LOGS_OK=true
fi

if [ "$NODE_CHECK" = "200" ]; then
    NODE_EXPORTER_OK=true
fi

if [ "$NGINX_CHECK" = "200" ]; then
    NGINX_EXPORTER_OK=true
fi

# Вывод результатов
if $ALL_SERVICES_ACTIVE; then
    echo "✅ ВСЕ ОСНОВНЫЕ СЛУЖБЫ АКТИВНЫ"
else
    echo "⚠️  НЕКОТОРЫЕ СЛУЖБЫ НЕ АКТИВНЫ"
fi

if $PROMETHEUS_TARGETS_OK; then
    echo "✅ Prometheus собирает метрики с 4 экспортеров"
else
    echo "⚠️  Prometheus: только $TARGETS_COUNT из 4 экспортеров"
fi

if $GRAFANA_OK; then
    echo "✅ Grafana работает и доступна"
    if [ "$DASH_COUNT" -gt 0 ] 2>/dev/null; then
        echo "✅ Дашборды созданы ($DASH_COUNT шт.)"
    else
        echo "⚠️  Дашборды не созданы - импортируйте через веб-интерфейс"
    fi
else
    echo "❌ Grafana недоступна"
fi

if $ELASTICSEARCH_OK; then
    echo "✅ Elasticsearch работает (статус: $ES_STATUS)"
else
    echo "❌ Elasticsearch недоступен"
fi

if $KIBANA_OK; then
    echo "✅ Kibana доступна"
else
    echo "❌ Kibana недоступна"
fi

if $LOGS_OK; then
    echo "✅ Логи собираются ($DOC_COUNT документов)"
else
    echo "⚠️  Логи не найдены в Elasticsearch"
fi

if $NODE_EXPORTER_OK; then
    echo "✅ Node Exporter метрики доступны"
else
    echo "⚠️  Node Exporter метрики недоступны"
fi

if $NGINX_EXPORTER_OK; then
    echo "✅ Nginx Exporter метрики доступны"
else
    echo "⚠️  Nginx Exporter метрики недоступны"
fi

