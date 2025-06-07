
#считываем данные об образе ОС
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "vm" {
  count       =  2
  name        = "vm${count.index}" #Имя ВМ в облачной консоли
  hostname    = "vm${count.index}"
  platform_id = "standard-v1"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }
  
  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-1.id
    nat                = true
  }

  metadata = {
    user-data          = "${file("./cloud-init.yml")}"
    }
  
  scheduling_policy { preemptible = true }
  }

resource "yandex_vpc_network" "network-1" {
  name        = "network1"
  }

  resource "yandex_vpc_subnet" "subnet-1" {
    name          = "subnet1"
    zone          = "ru-central1-a"
    v4_cidr_blocks= ["192.168.10.0/24"]
    network_id    = "${yandex_vpc_network.network-1.id}"
  }

resource "yandex_lb_target_group" "tg-1" {
  name        = "tg-1"

  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.vm[0].network_interface.0.ip_address
  }
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.vm[1].network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb-1" {
  name = "lb-1"
  deletion_protection = "false"
  listener {
    name = "listener-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.tg-1.id
    healthcheck {
      name = "http"
        http_options {
          port = 80
          path = "/"
      }
    }
  }
}
