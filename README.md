#  Курсовая работа на профессии "DevOps-инженер с нуля Лычагин Н.В."

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

Заходим на yandex.cloud и проверяем результат поднятия инфраструктуры:

**Проверка ВМ**:
![ВМ](https://github.com/Nikich828/coursework/blob/main/30.jpeg)

Проверим сеть, должен быть развернут один VPC. Webservers,elasticsearch в приватной подсети, а prometheus, grafana, kibana и alb в публичной.

**Проверка сети**:
![Сеть](https://github.com/Nikich828/coursework/blob/main/31.jpeg)
![VPC](https://github.com/Nikich828/coursework/blob/main/24.jpeg)

Проверим Target Group, Backend Group, HTTP router, Application load balancer:

**Проверка Target Group, Backend Group, HTTP router, Application load balancer**:
![Сеть](https://github.com/Nikich828/coursework/blob/main/19.jpeg)
![VPC](https://github.com/Nikich828/coursework/blob/main/20.jpeg)
![VPC](https://github.com/Nikich828/coursework/blob/main/21.jpeg)
![VPC](https://github.com/Nikich828/coursework/blob/main/22.jpeg)
![VPC](https://github.com/Nikich828/coursework/blob/main/23.jpeg)


Теперь группы безопастности и балансировщик:

**Проверка групп безопастности**:
![Сеть](https://github.com/Nikich828/coursework/blob/main/25.jpeg)

**Проверка балансировщика**:
![Сеть](https://github.com/Nikich828/coursework/blob/main/29.jpeg)

Перейдем по публичному адресу балансировщика **[Курсовая работа](http://158.160.223.127)**:

**Сайт курсовая работа**:
![Курсовая работа](https://github.com/Nikich828/coursework/blob/main/13.jpeg)

Проверим доступ к grafana и проверим работу дашборда по ссылке **[Grafana](http://158.160.19.43:3000/d/use-dashboard/dashboard?orgId=1&from=now-6h&to=now&timezone=browser&var-instance=$__all&var-mountpoint=$__all&var-device=$__all&refresh=10s)**:

**Проверка доступа к Grafana и работы дашборда**:
![Grafana](https://github.com/Nikich828/coursework/blob/main/11.jpeg)
![Дашборд](https://github.com/Nikich828/coursework/blob/main/12.jpeg)
![Дашборд](https://github.com/Nikich828/coursework/blob/main/28.jpeg)


Проверим работу ELK, для этого перейдем по ссылке **[Kibana](http://158.160.85.121:5601/app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:60000),time:(from:now-15m,to:now))&_a=(columns:!(),filters:!(),index:'8fb2eab4-198f-48d2-b726-b10f353c3387',interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc))))**

**Проверяем работу ELK**:
![Курсовая работа](https://github.com/Nikich828/coursework/blob/main/15.jpeg)
![Курсовая работа](https://github.com/Nikich828/coursework/blob/main/27.jpeg)


Теперь проверим снапшоты:

**Проверяем работу snapshot**:
![Курсовая работа](https://github.com/Nikich828/coursework/blob/main/26.jpeg)
![Курсовая работа](https://github.com/Nikich828/coursework/blob/main/32.jpeg)

### Вывод

В рамках курсовой работы была успешно спроектирована и развернута отказоустойчивая облачная инфраструктура в Yandex Cloud с использованием современных DevOps-практик и инструментов.

Достигнутые цели:

Отказоустойчивая архитектура веб-сервиса: Созданы два идентичных веб-сервера в разных зонах доступности, объединенные через Application Load Balancer. Данная конфигурация обеспечивает высокую доступность приложения и распределение нагрузки.

Комплексная система мониторинга: Развернут стек Prometheus + Grafana. С помощью Node Exporter и Nginx Log Exporter осуществляется сбор системных метрик и метрик доступа веб-серверов. В Grafana настроены информативные дашборды с пороговыми значениями (thresholds) для ключевых показателей (CPU, RAM, диски, сеть, HTTP-запросы), что позволяет оперативно отслеживать состояние инфраструктуры и выявлять аномалии.

Централизованный сбор и анализ логов: Развернут стек ELK (Elasticsearch, Kibana, Filebeat). Filebeat, установленный на веб-серверах, собирает логи Nginx (access.log, error.log) и отправляет их в Elasticsearch для индексации и хранения. Kibana предоставляет удобный интерфейс для визуализации, поиска и анализа логов.

Безопасная сетевая архитектура: Инфраструктура развернута в рамках одного VPC с разделением на публичные и приватные подсети. Настроены Security Groups, строго ограничивающие входящий трафик только к необходимым портам сервисов. Реализована концепция Bastion Host, который служит единственной контролируемой точкой входа для SSH-доступа ко всем внутренним хостам.

Автоматизация и управление конфигурацией: Вся инфраструктура описана в коде с помощью Terraform, что обеспечивает повторяемость, контролируемость изменений и возможность быстрого восстановления. Конфигурация всех сервисов и их установка автоматизированы с помощью Ansible.

Резервное копирование: Настроено автоматическое ежедневное создание снапшотов дисков всех виртуальных машин с ограничением времени хранения в одну неделю. Это обеспечивает базовый уровень восстановления инфраструктуры и данных в случае сбоев.

Итог: В результате была создана полнофункциональная, безопасная и отказоустойчивая платформа. Инфраструктура обладает встроенными механизмами для наблюдения за своим состоянием (мониторинг, логи), восстановления (снапшоты) и безопасного управления. Использование подходов Infrastructure as Code и конфигурационного управления позволяет эффективно сопровождать, масштабировать и модифицировать данную систему. Все задачи, поставленные в курсовой работе, выполнены в полном объеме.