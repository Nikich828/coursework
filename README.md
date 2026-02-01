#  Курсовая работа на профессии "DevOps-инженер с нуля"

Содержание
==========
* [Задача](#Задача)
* [Инфраструктура](#Инфраструктура)
    * [Сайт](#Сайт)
    * [Мониторинг](#Мониторинг)
    * [Логи](#Логи)
    * [Сеть](#Сеть)
    * [Резервное копирование](#Резервное-копирование)
    * [Дополнительно](#Дополнительно)
* [Выполнение работы](#Выполнение-работы)
* [Критерии сдачи](#Критерии-сдачи)
* [Как правильно задавать вопросы дипломному руководителю](#Как-правильно-задавать-вопросы-дипломному-руководителю) 

---------
## Задача
Ключевая задача — разработать отказоустойчивую инфраструктуру для сайта, включающую мониторинг, сбор логов и резервное копирование основных данных. Инфраструктура должна размещаться в [Yandex Cloud](https://cloud.yandex.com/).

**Примечание**: в курсовой работе используется система мониторинга Prometheus. Вместо Prometheus вы можете использовать Zabbix. Задание для курсовой работы с использованием Zabbix находится по [ссылке](https://github.com/netology-code/fops-sysadm-diplom/blob/diplom-zabbix/README.md).

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**   

## Инфраструктура
Для развёртки инфраструктуры используйте Terraform и Ansible. 

Параметры виртуальной машины (ВМ) подбирайте по потребностям сервисов, которые будут на ней работать. 

Ознакомьтесь со всеми пунктами из этой секции, не беритесь сразу выполнять задание, не дочитав до конца. Пункты взаимосвязаны и могут влиять друг на друга.

### Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.

Создайте [Target Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/target-group), включите в неё две созданных ВМ.

Создайте [Backend Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/backend-group), настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP.

Создайте [HTTP router](https://cloud.yandex.com/docs/application-load-balancer/concepts/http-router). Путь укажите — /, backend group — созданную ранее.

Создайте [Application load balancer](https://cloud.yandex.com/en/docs/application-load-balancer/) для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

Протестируйте сайт
`curl -v <публичный IP балансера>:80` 

### Мониторинг
Создайте ВМ, разверните на ней Prometheus. На каждую ВМ из веб-серверов установите Node Exporter и [Nginx Log Exporter](https://github.com/martin-helmich/prometheus-nginxlog-exporter). Настройте Prometheus на сбор метрик с этих exporter.

Создайте ВМ, установите туда Grafana. Настройте её на взаимодействие с ранее развернутым Prometheus. Настройте дешборды с отображением метрик, минимальный набор — Utilization, Saturation, Errors для CPU, RAM, диски, сеть, http_response_count_total, http_response_size_bytes. Добавьте необходимые [tresholds](https://grafana.com/docs/grafana/latest/panels/thresholds/) на соответствующие графики.

### Логи
Cоздайте ВМ, разверните на ней Elasticsearch. Установите filebeat в ВМ к веб-серверам, настройте на отправку access.log, error.log nginx в Elasticsearch.

Создайте ВМ, разверните на ней Kibana, сконфигурируйте соединение с Elasticsearch.

### Сеть
Разверните один VPC. Сервера web, Prometheus, Elasticsearch поместите в приватные подсети. Сервера Grafana, Kibana, application load balancer определите в публичную подсеть.

Настройте [Security Groups](https://cloud.yandex.com/docs/vpc/concepts/security-groups) соответствующих сервисов на входящий трафик только к нужным портам.

Настройте ВМ с публичным адресом, в которой будет открыт только один порт — ssh. Настройте все security groups на разрешение входящего ssh из этой security group. Эта вм будет реализовывать концепцию bastion host. Потом можно будет подключаться по ssh ко всем хостам через этот хост.

### Резервное копирование
Создайте snapshot дисков всех ВМ. Ограничьте время жизни snaphot в неделю. Сами snaphot настройте на ежедневное копирование.

### Ход работы:

В ходе работ необходимо развернуть 7 ВМ:

- web-server-1
- web-server-2
- bastion-host
- prometheus-server
- grafana-server
- elasticsearch-server
- kibana-server

Переходим в папку terraform и вводим следующие команды:

```bash
terraform init      # Инициализация проекта
terraform validate  # Проверка синтаксиса
terraform plan      # Планирование изменений
terraform apply     # Применение инфраструктуры
```
**Результат применения инфраструктуры**:
![Результат применения инфраструктуры](https://github.com/Nikich828/coursework/blob/main/1.jpeg)

Дальше переходим в директорию ansible, удаляем файл с информацией о серверах, к которым подключались, чтобы не было ошибки при подлючении по ssh и запускаем copy_file.yml для переноса приватного ключа на бастион:

```bash
rm /home/nvlychagin/.ssh/known_hosts             # Удаление файла known_hosts для очистки кеша SSH подключений
ansible-playbook -i inventory.ini copy_file.yml  # Запуск Ansible playbook с указанием inventory файла
```
**Процесс применения плейбука copy_file.yml**:
![Процесс применения плейбука copy_file.yml](https://github.com/Nikich828/coursework/blob/main/2.jpeg)

Теперь запускаем плейбук install_nginx.yml для установки Nginx на webservers:

```bash
ansible-playbook -i inventory.ini install_nginx.yml
```
**Процесс применения плейбука install_nginx.yml**:
![Процесс применения плейбука install_nginx.yml](https://github.com/Nikich828/coursework/blob/main/3.jpeg)

После устанавливаем Prometheus (для собирания и хранения метрик) с помощью плейбука install_prometheus.yml:

```bash
ansible-playbook -i inventory.ini install_prometheus.yml
```
**Процесс применения плейбука install_prometheus.yml**:
![Процесс применения плейбука install_prometheus.yml](https://github.com/Nikich828/coursework/blob/main/4.jpeg)

Теперь node-exporter на webservers для сбора метрик на этих серверах:

```bash
ansible-playbook -i inventory.ini install_node-exporter.yml
```
**Процесс применения плейбука install_node-exporter.yml**:
![Процесс применения плейбука install_node-exporter.yml](https://github.com/Nikich828/coursework/blob/main/5.jpeg)

Далее также для webservers устнавливаем nginx-log-exporter.yml для сборки логов Nginx и создания метрик:

```bash
ansible-playbook -i inventory.ini install_nginx-log-exporter.yml
```
**Процесс применения плейбука install_nginx-log-exporter.yml**:
![Процесс применения плейбука install_nginx-log-exporter.yml](https://github.com/Nikich828/coursework/blob/main/6.jpeg)

Установим grafana для визуализации метрик в дашбордах:

```bash
ansible-playbook -i inventory.ini install_grafana.yml
```
**Процесс применения плейбука install_grafana.yml**:
![Процесс применения плейбука install_grafana.yml](https://github.com/Nikich828/coursework/blob/main/7.jpeg)

Далее установим elasticsearch, которая примиает, индексирует и хранит логи:

```bash
ansible-playbook -i inventory.ini install_elasticsearch.yml
```
**Процесс применения плейбука install_elasticsearch.yml**:
![Процесс применения плейбука install_elasticsearch.yml](https://github.com/Nikich828/coursework/blob/main/8.jpeg)

Теперь установим kibana, задача которой собирать данные из elasticsearch и визуализирует их:

```bash
ansible-playbook -i inventory.ini install_kibana.yml
```
**Процесс применения плейбука install_kibana.yml**:
![Процесс применения плейбука install_kibana.yml](https://github.com/Nikich828/coursework/blob/main/9.jpeg)

И наконец приступи к установки filebeat для сбора логов:

```bash
ansible-playbook -i inventory.ini install_filebeat.yml
```

**Процесс применения плейбука install_filebeat.yml**:
![Процесс применения плейбука install_filebeat.yml](https://github.com/Nikich828/coursework/blob/main/10.jpeg)

Проверим доступ к grafana и проверим работу дашборда по ссылке **[Grafana](http://84.252.137.244:3000)**:

**Проверка доступа к Grafana и работы дашборда**:
![Grafana](https://github.com/Nikich828/coursework/blob/main/11.jpeg)
![Дашборд](https://github.com/Nikich828/coursework/blob/main/12.jpeg)
![Дашборд](https://github.com/Nikich828/coursework/blob/main/28.jpeg)

