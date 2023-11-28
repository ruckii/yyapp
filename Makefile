UBUNTU = jammy
ARCH = amd64

DB = $(shell date --rfc-3339=ns | md5sum | cut -c -32)
REPL = $(shell date --rfc-3339=ns | md5sum | cut -c -32)

.DEFAULT_GOAL := info
# uname := $(shell uname -s)

info:
	@echo "--> Bingo server <<The Hard Way>> <--"

.update:
	sudo apt update

.upgrade: .update
	sudo apt upgrade --assume-yes --quiet

.hostname-master:
	sudo hostnamectl hostname node-01

.hostname-slave:
	sudo hostnamectl hostname node-02

.dns-resolver: .update
	sudo apt install --assume-yes --quiet avahi-daemon
	sudo systemctl enable avahi-daemon
	sudo systemctl start avahi-daemon
	sudo systemctl status avahi-daemon

test: .update
	sudo apt install --assume-yes --quiet wrk

.docker: .upgrade
	#echo $(UBUNTU)$(ARCH)
	#sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
	#sudo rm /etc/apt/keyrings/docker.gpg
	#sudo rm /etc/apt/sources.list.d/docker.list
# Add Docker's official GPG key:
	sudo apt-get install --assume-yes --quiet ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Add the repository to Apt sources:
	echo "deb [arch=$(ARCH) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(UBUNTU) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	sudo usermod -aG docker ${USER}

.timesync:
#	Откройте файл /etc/systemd/timesyncd.conf, для этого в терминале выполните команду:
	cat /etc/systemd/timesyncd.conf
#       Укажите адреса рекомендуемых серверов в секции [Time] в параметре FallbackNTP=, например:
#       FallbackNTP=ntp0.NL.net ntp2.vniiftri.ru ntp.ix.ru ntps1-0.eecsit.tu-berlin.de
#       Перезапустите сервис синхронизации времени:
	sudo systemctl restart systemd-timesyncd
	sudo systemctl status systemd-timesyncd
	timedatectl

.downloads:
	curl --progress-bar --output ./bin/bingo --location https://storage.yandexcloud.net/final-homework/bingo
	curl --progress-bar --output ./bin/caddy --location https://caddyserver.com/api/download?os=linux&arch=amd64
	touch .downloads

.tools:
	sudo curl --progress-bar --output /usr/bin/yq --location https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/bin/yq

.build: .downloads
	docker compose build

.configure-master: .upgrade .timesync .hostname-master .docker

.configure-slave: .upgrade .timesync .hostname-slave .docker

master: .configure-master .passwords .build
	docker compose up bingo-server-master

slave: .configure-slave .build
	# TODO: passwords
	docker compose up bingo-server-slave

.passwords: .tools
	sudo curl --output /usr/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/bin/yq
	echo "db_password=$(DB)" > .passwords
	echo "db_repl_password=$(REPL)" >> .passwords
	echo $(DB) > ./postgres/db_password.txt
	echo $(REPL) > ./postgres/db_repl_password.txt
	yq -i '.postgres_cluster.password = "$(DB)"' ./bingo/config-server.yaml
	yq -i '.postgres_cluster.password = "$(DB)"' ./bingo/config-prepare-db.yaml

clean:
	echo "xxx" > ./postgres/db_password.txt
	echo "xxx" > ./postgres/db_repl_password.txt
	yq --inplace '.postgres_cluster.password = "xxx"' ./bingo/config-server.yaml
	yq --inplace '.postgres_cluster.password = "xxx"' ./bingo/config-prepare-db.yaml
