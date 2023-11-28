UBUNTU = jammy
ARCH = amd64
.DEFAULT_GOAL := info
# uname := $(shell uname -s)

info:
	@echo "--> Bingo server <<The Hard Way>> <--"

update:
	sudo apt update && sudo apt upgrade -y

init: update
	sudo apt install wrk

docker:
	#echo $(UBUNTU)$(ARCH)
	#sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
	#sudo rm /etc/apt/keyrings/docker.gpg
	#sudo rm /etc/apt/sources.list.d/docker.list
# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Add the repository to Apt sources:
	echo "deb [arch=$(ARCH) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(UBUNTU) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	#sudo docker run hello-world
	sudo usermod -aG docker ${USER}
date:
	@date

timesync:
#	Откройте файл /etc/systemd/timesyncd.conf, для этого в терминале выполните команду:
	cat /etc/systemd/timesyncd.conf
#       Укажите адреса рекомендуемых серверов в секции [Time] в параметре FallbackNTP=, например:
#       FallbackNTP=ntp0.NL.net ntp2.vniiftri.ru ntp.ix.ru ntps1-0.eecsit.tu-berlin.de
#       Перезапустите сервис синхронизации времени:
	sudo systemctl restart systemd-timesyncd
	sudo systemctl status systemd-timesyncd
	timedatectl
