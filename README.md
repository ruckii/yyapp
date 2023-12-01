![Bingo](https://github.com/ruckii/yyapp/assets/1169824/5d9961d5-a9f1-41ae-8630-14673ecf3488)

# Bingo сервис "Кровь и слёзы"
*Благодарность Young&&Yandex команде за бесценный опыт!*

# Исследование и решения

## Запуск приложения [~4 часa]

```bash
wget https://storage.yandexcloud.net/final-homework/bingo
file bingo # --> bingo: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
chmod +x bingo
./bingo # --> Hello world
./bingo --help
./bingo version
./bingo print_current_config
./bingo print_default_config
./bingo print_default_config > bingo.conf
./bingo --help
./bingo run_server --help
./bingo run_server # --> Crashed
sudo ./bingo run_server # --> Didn't your mom teach you not to run anything incomprehensible from root?
strace bingo
strace ./bingo
strace ./bingo get_current_config
strace ./bingo print_current_config # --> found failed access to file /opt/bingo/config.yaml
sudo mkdir /opt/bingo
./bingo print_default_config > config.yaml
sudo cp config.yaml /opt/bingo/
./bingo print_current_config
strace ./bingo run_server
#--✂--edit config.yaml--✂--
#--✂--run postgres in docker--✂--
./bingo prepare_db # --> ~20min
#--✂--install DBeaver (https://dbeaver.io/)--✂--
#--✂--inspect bingo DB structure--✂--
./bingo run_server # --> Still crashed
strace ./bingo run_server # --> found failed access to file /opt/bongo/logs/21b3c4259a/main.log
sudo mkdir -p /opt/bongo/logs/21b3c4259a/
sudo touch /opt/bongo/logs/21b3c4259a/main.log
./bingo run_server
strace ./bingo run_server # --> found insufficient rights on file
sudo chmod 0666 /opt/bongo/logs/21b3c4259a/main.log
./bingo run_server # --> 30sec startup
./bingo run_server &
tail -f /opt/bongo/logs/21b3c4259a/main.log
```


## Поход в корень
Смотрим открытые порты

```bash
ss -tunlp # --> ipv6 4922/tcp
```

http://localhost:4922 # --> не помню деталей

Нашёл код:
```
My congratulations.
You were able to start the server.
Here's a secret code that confirms that you did it.
--------------------------------------------------
code:         yoohoo_server_launched
--------------------------------------------------
```

## Web-proxy [1 день]
Выбираю прокси, ранее с nginx уже сталкивался, решил посмотреть в сторону альтернативных.
Между traefic и caddy выбрал и настроил последний.
Сначала использовал готовый образ с dockerhub, потом собрал свой (в готовом столкнулся с какой-то проблемой, деталей не помню, вроде бы захотел Caddyfile добавить свой, а не монтировать через volume).

Из плюсов caddy:
- относительно понятная и полная документация
- http/3 и самоподписанный динамический TLS
- экспорт метрик в формате prometheus
- много разных способов балансировки
- поддержка healthcheck для upstream-серверов

Минусы:
 - нет кеширования из коробки, нужно пересобирать с модулями (пришлось 🚲🦯, см. код Caddyfile, Makefile и историю коммитов)

## Планирую структуру и отказоустойчивость

Решение делать всё в контейнерах принято.

### Образы

По результатам множества проб и ошибок использованы следующие образы:

- база данных - готовый образ [bitnami/postgresql](https://hub.docker.com/r/bitnami/postgresql) с поддержкой репликации
- собираю init образ для запуска **bingo prepare_db** на базе gcr.io/distroless/static-debian12:nonroot
- собираю образ для **bingo run_server** на базе ubuntu
- веб-прокси - сначала использую готовый образ [caddy](https://hub.docker.com/_/caddy), потом собираю свой

### Тесты

Ставлю и пробую wrk. Ранее, кажется при просмотре strace и ld вывода от bingo заметил наличие библиотеки троттлинга для golang. На тестах замечаю, что RPS от одного сервиса bingo ограничен ~100. Нужно минимум 2 экземпляра для выполнения требований ТЗ.

Замечаю, что bingo:
- падает по OOM
- I feel bad вместо pong на healthcheck

Добавляю проверку в docker-образ (сначала был таймаут ~35 секунд, чтобы приложение успело запуститься и начать отдавать **pong**, когда разобрался с ускорением запуска - уменьшил таймауты):

**bingo-server.Dockerfile**

```dockerfile
HEALTHCHECK --interval=5s --timeout=2s \
    CMD ./healthcheck.sh || kill 1 
```

**healthcheck.sh**
```bash
#!/bin/bash
STATUS=$(curl --silent http://localhost:4922/ping)
if [[ $STATUS == "pong" ]]; then
  echo "OK"
  exit 0
else
  echo "KO"
  exit 1
fi
```

Прикручиваю бомж-мониторинг доступности, после проксирования через caddy:

```bash
#!/bin/bash

while true;
  do
  STATUS=$(curl --silent -k https://node-01.local/ping) # [OK] pong / [KO] I feel bad
  curl --fail --silent -k https://node-01.local/ping > /dev/null
  if [[ $? == 7 ]]; then
    echo -n "X"
  elif [[ $STATUS == "I feel bad" ]]; then
    echo -n "B"
  else
    echo -n "."
  fi
sleep 1;
done
```

Изучаю картину доступности примерно в таком формате:

```
...........................................................BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB.............
................................................................................................BBBBBBBBBBBBBBB
BBBBBBBBBBBBBB.................................................................................................
...............................................................................................................
.......................................................................XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX..
...............................................................................................................
...............BB..............................................................................................
```


### Оркестрация

Сначала делал всё на собственной ВМ (виртуальная машина поднятая на связке [Ubuntu Multipass + Windows 10 Hyper-V](https://multipass.run/docs/installing-on-windows#heading--hyper-v) - *крайне рекомендую, при интеграции сходной с WSL - лучшая изоляция, стабильность и docker*)

Пишу compose.yaml:

- для оркестрации делаю зависимости сервисов для правильного старта и останова
- делаю healthcheck-проверки, чтобы сервисы не поднимались раньше, чем инициализируются те, от которых зависят (postgresql --> bingo-prepare-bd --> bingo-server --> caddy)
- добавляю persistent-том для базы данных
- пробую запускать несколько экземпляров контейнеров с bingo-server и настраивать балансировку

Хотел попробовать на Docker swarm-mode, но отказался из-за того, что требуется 3 ноды для кворума. На 2 нодах можно собрать, и даже будет работать, но только при выходе из строя worker-ноды. Если выключить ноду, на коорой controller - всё падает. Неприемлемо.

Когда получаю приемлемый результат с docker compose, планирую развёртывание в Yandex Cloud.

_При этом по результатам предварительных тестов нагрузки понимаю, что можно развернуть на 1 ВМ (2 GB RAM, 2 vCPU)._

### Целевая платформа

_См. картинку выше._

Развертывание ВМ, сети, подсети c помощью Terraform.

### Автоматизация (CI/CD)

Времени и ресурсов было мало, GitHub Actions потыкал палочкой и решил по старинке через Makefile.
Основные моменты развёртывания автоматизировал с учётом master/slave серверов под Ubuntu 22.04.

```bash

# 1. Клонируем репозиторий

git clone https://github.com/ruckii/yyapp

# 2. Ставим make

sudo apt update
sudo apt install make

# 3. Делаем разные вещи используя make

cd yyapp
make
'--> Bingo service <<The Hard Way>> <--'

# 4. Например ставим master ноду
make master
#--✂--идёт раскатка и подпинывание ногой--✂--

# 5. Или slave ноду
make slave
#--✂--идёт раскатка и подпинывание ногой--✂--

# 6. Когда устали

make clean
#--✂--идёт удаление всякого и идём снова на пункт 4. или 5.--✂--
```
Фичи (таргеты):
- info - не доделано
- update/upgrade - обновления кеша репозиториев, обновление ОС
- hostname-master/hostname-slave - установка имени хоста
- dns-resolver - установка и настройка avahi (zeroconf local DNS резольвер)
- ban-google - ускорение запуска bingo service
- cache-long-dummy - костыльно-велосипедное решение для кеширования
- test - запуск тестов wrk
- docker - установка настрока docker
- timesync - настройка времени по рекомендациям из статьи Yandex Cloud
- downloads - скачивание bingo и caddy
- tools - установка wrk, yq
- build - сборка образов
- configure-master/configure-slave - настройка нод
- master/slave - запуск сервисов на нодах
- passwords-master/passwords-slave - генерация и заполнение паролей в конфигах postgres и bingo, при этом на slave-ноде запрашиваются пароли в интерактиве, чтобы кластер собрался
- clean - очистка от всяких артефактов (не всех), замена паролей заглушками

# Разные вещи

## Ускорение старта

Сначала я думал, что долгий старт это норма. Потом нашёл код, просматривая приложение bingo в блокноте. Далее нашёл http://8.8.8.8 в строках бинарника, открыл и увидел таймаут. 

Далее:

```bash
ip route add blackhole 8.8.8.8
```

## Avahi - zeroconf локальное разрешение имён (*.local)

sudo apt install avahi-daemon
sudo systemctl start avahi-daemon
sudo systemctl status avahi-daemon
sudo systemctl enable avahi-daemon

## Оптимизация запросов БД

Запускаю DBeaver и в процессе прогонки тестов смотрю сессии и собираю запросы. Запускаю вручную с профилировкой.

```sql
explain (analyze,verbose on)
```
Смотрю планы выполнения запросов, добавляю индексы и/или первичные ключи.

Самая сложность была с _GET /sessions_ - оптимизировал по шагам, постепенно добавляя JOIN и ORDER, попутно создавая индексы.

#### Поворот не туда

Попутно пошёл по кривой дорожке, попробовав преобразовать таблицу **sessions** и другие, с которыми она соединяется в columnar _table_. 
Для этого БД развёртывал на готовом образе [citusdata/citus](https://hub.docker.com/r/citusdata/citus). Также, много думал на тему шардинга таблиц по двум нодам.

```sql
-- создаём целевую columnar таблицу
CREATE TABLE public.customers_col (
	id int4 NOT NULL DEFAULT nextval('customers_id_seq'::regclass),
	"name" varchar(80) NOT NULL,
	surname varchar(80) NOT NULL,
	birthday date NOT NULL,
	email varchar(256) NOT NULL,
	CONSTRAINT customers_pk PRIMARY KEY (id)
) USING columnar;

-- копируем данные из исходной
INSERT INTO customers_col
SELECT * FROM customers;

-- переименовываем, исходную и целевую, меняя их местами
...
```

Columnar таблицы по скорости не сильно выигрывали на текущих запросах у row-based, что, в прочем было ожидаемо, хотя была надежда что за счёт уменьшения размера БД она будет работать в памяти.

#### Результат

В итоге оптимизировал исходную таблицу, чтобы повторные запросы не отваливались по таймауту.

Все оптимизации:
```sql
-- PK
ALTER TABLE public.sessions ADD CONSTRAINT sessions_pk PRIMARY KEY (id);
ALTER TABLE public.customers ADD CONSTRAINT customers_pk PRIMARY KEY (id);
ALTER TABLE public.movies ADD CONSTRAINT movies_pk PRIMARY KEY (id);
-- Indexes
CREATE INDEX sessions_movie_id_idx ON public.sessions USING btree (movie_id);
CREATE INDEX movies_year_name_idx ON public.movies USING btree (year DESC, name);
CREATE INDEX customers_surname_idx ON public.customers (surname,"name",birthday DESC,id DESC);
CREATE INDEX movies_year_idx ON public.movies ("year" DESC,"name",id DESC);
```

## Мониторинг

- Yandex Monitoring для VM (диски, CPU), NLB (пакеты)
- Grafana+Prometheus для caddy (на домашнем ПК), чтобы следить за RPS, длительностью запросов и ошибками HTTP


# English version
## Deployment steps

1. Clone repository

  git clone https://github.com/ruckii/yyapp

2. Install **make** utility

  sudo apt update
  sudo apt install make

3. Do other stuff using **make**

  cd yyapp
  make
