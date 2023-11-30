terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a"
}

resource "yandex_compute_instance" "node-01" {
  name        = "node-01"
  description = "Bingo cluster node #1"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = "fd89cudngj3s2osr228p"
      size     = 16
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_compute_instance" "node-02" {
  name        = "node-02"
  description = "Bingo cluster node #2"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = "fd89cudngj3s2osr228p"
      size     = 16
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_vpc_network" "vnet-01" {
  name        = "vnet-01"
  description = "Virtual network #1"
}

resource "yandex_vpc_subnet" "subnet-01" {
  name           = "subnet-01"
  description    = "Virtual network #1 - Subnet #1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.vnet-01.id
  v4_cidr_blocks = ["10.10.10.0/24"]
}

output "internal_ip_address_node-01" {
  value = yandex_compute_instance.node-01.network_interface.0.ip_address
}

output "internal_ip_address_node-02" {
  value = yandex_compute_instance.node-02.network_interface.0.ip_address
}

output "external_ip_address_node-01" {
  value = yandex_compute_instance.node-01.network_interface.0.nat_ip_address
}

output "external_ip_address_node-02" {
  value = yandex_compute_instance.node-02.network_interface.0.nat_ip_address
}
