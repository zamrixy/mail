# mail
myCode
############

SSH соединение постоянно обрывается из-за таймаута:
nano /etc/ssh/ssh/ssh_config
ServerAliveInterval 60
ServerAliveCountMax 10
-----------------------------------------------
Для удаления автоматически созданных ресурсов Терраформ. Из папки с конфигами терраформ
запускаем:
terraform destroy
-----------------------------------------------
Terraform
main.tf

data "vkcs_networking_network" "extnet" {
   name = "ext-net"
}

resource "vkcs_networking_router" "router" {
   name                = "router"
   admin_state_up      = true
   external_network_id = data.vkcs_networking_network.extnet.id
}

resource "vkcs_networking_router_interface" "db" {
   router_id = vkcs_networking_router.router.id
   subnet_id = vkcs_networking_subnet.lb.id
}

#сеть
resource "vkcs_networking_network" "lb" {
  name = "network"
}

resource "vkcs_networking_subnet" "lb" {
  name = "subnet"
  cidr = "192.168.199.0/24"
  network_id = "${vkcs_networking_network.lb.id}"
}


#создание машин и балансировщика
 #переменные для имен ключей и зон
variable "key_pair_name" {
  type = string
  default = "home"
}

variable "availability_zone_name" {
  type = string
  default = "MS1"
}

variable "availability_zone_name_2" {
  type = string
  default = "GZ1"
}


#Далее настройки для двух машин и балансировщика из примера в документации vkcloud

data "vkcs_images_image" "compute" {
   name = "Ubuntu-18.04-Standard"
}

data "vkcs_compute_flavor" "compute" {
  name = "Basic-1-1-10"
}

resource "vkcs_compute_instance" "compute_1" {
  name            = "web1"
  flavor_id       = data.vkcs_compute_flavor.compute.id
  security_groups = ["default","ssh"]
  image_id = data.vkcs_images_image.compute.id
  key_pair        = var.key_pair_name
  availability_zone   = var.availability_zone_name

  network {
    uuid = vkcs_networking_network.lb.id
    fixed_ip_v4 = "192.168.199.110"
  }

  depends_on = [
    vkcs_networking_network.lb,
    vkcs_networking_subnet.lb
  ]
}

resource "vkcs_compute_instance" "compute_2" {
  name            = "web2"
  flavor_id       = data.vkcs_compute_flavor.compute.id
  security_groups = ["default","ssh"]
  image_id = data.vkcs_images_image.compute.id
  key_pair        = var.key_pair_name
  availability_zone    = var.availability_zone_name_2

  network {
    uuid = vkcs_networking_network.lb.id
    fixed_ip_v4 = "192.168.199.111"
  }

  depends_on = [
    vkcs_networking_network.lb,
    vkcs_networking_subnet.lb
  ]
}

resource "vkcs_lb_loadbalancer" "loadbalancer" {
  name = "loadbalancer"
  vip_subnet_id = "${vkcs_networking_subnet.lb.id}"
  tags = ["tag1"]
}

resource "vkcs_lb_listener" "listener" {
  name = "listener"
  protocol = "HTTP"
  protocol_port = 8080
  loadbalancer_id = "${vkcs_lb_loadbalancer.loadbalancer.id}"
}

resource "vkcs_lb_pool" "pool" {
  name = "pool"
  protocol = "HTTP"
  lb_method = "ROUND_ROBIN"
  listener_id = "${vkcs_lb_listener.listener.id}"
}

resource "vkcs_lb_member" "member_1" {
  address = "192.168.199.110"
  protocol_port = 8080
  pool_id = "${vkcs_lb_pool.pool.id}"
  subnet_id = "${vkcs_networking_subnet.lb.id}"
  weight = 0
}

resource "vkcs_lb_member" "member_2" {
  address = "192.168.199.111"
  protocol_port = 8080
  pool_id = "${vkcs_lb_pool.pool.id}"
  subnet_id = "${vkcs_networking_subnet.lb.id}"
}

##load balancer float ip
resource "vkcs_networking_floatingip" "lb_fip" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_networking_floatingip_associate" "lb_fip" {
  floating_ip = vkcs_networking_floatingip.lb_fip.address
  port_id = vkcs_lb_loadbalancer.loadbalancer.vip_port_id
}


output "loadbalancer_ip" {
value = vkcs_networking_floatingip.lb_fip.address
}

#float ip 1 инстанс
resource "vkcs_networking_floatingip" "fip" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_compute_floatingip_associate" "fip" {
  floating_ip = vkcs_networking_floatingip.fip.address
  instance_id = vkcs_compute_instance.compute_1.id
}

output "instance_fip" {
  value = vkcs_networking_floatingip.fip.address
}

#float ip 2 инстанс
resource "vkcs_networking_floatingip" "fip_compute2" {
  pool = data.vkcs_networking_network.extnet.name
}

resource "vkcs_compute_floatingip_associate" "fip_compute2" {
  floating_ip = vkcs_networking_floatingip.fip_compute2.address
  instance_id = vkcs_compute_instance.compute_2.id
}

output "instance_fip_compute2" {
  value = vkcs_networking_floatingip.fip_compute2.address
}


---------------------------------

###Парсим вывод ip адреса инстансов
terraform apply | tail -n3 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -n2 > instans_ip

###Парсим вывод ip адреса балансировщика
terraform apply | tail -n1 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" > lb_ip

------------------------------------
####vkcs_provider.tf 

terraform {
     required_providers {

        openstack = {
            source  = "terraform-provider-openstack/openstack"
            version = "~> 1.46.0"
         }

        vkcs = {
            source = "vk-cs/vkcs"
            version = "~> 0.1.12"
         }

     }
 }

 provider "vkcs" {
     # Your user account.
     username = "maserati_1@mail.ru"

     # The password of the account
     password = "Kol-1Kut-2Kak-3"

     # The tenant token can be taken from the project Settings tab - > API keys.
     # Project ID will be our token.
     project_id = "5c051da5877d4a11b3a22f8f8f0c8729"

     # Region name
     region = "RegionOne"

     auth_url = "https://infra.mail.ru:35357/v3/"
 }

----------------------------------------
##### cloud.conf
#source cloud.conf     ввести эту команду, чтоб заработало


 #!/usr/bin/env bash

 export OS_AUTH_URL="https://infra.mail.ru:35357/v3/"

 export OS_PROJECT_ID="5c051da5877d4a11b3a22f8f8f0c8729"
 export OS_REGION_NAME="RegionOne"
 unset OS_PROJECT_NAME
 unset OS_PROJECT_DOMAIN_ID

 # unset v2.0 items in case set
 unset OS_TENANT_ID
 unset OS_TENANT_NAME

 if [[ -z $OS_USERNAME ]] || [[ -z $OS_PASSWORD ]] || [[ "$OS_USERNAME" != "maserati_1@mail.ru" ]]; then

 export OS_USERNAME="maserati_1@mail.ru"
 export OS_USER_DOMAIN_NAME="users"

 # With Keystone you pass the keystone password.
 #echo "Please enter your OpenStack Password for project $OS_PROJECT_ID as user $OS_USERNAME: "
 #read -sr OS_PASSWORD_INPUT
 export OS_PASSWORD="Kol-1Kut-2Kak-3"
 #export OS_PASSWORD=$OS_PASSWORD_INPUT

 fi

 export OS_INTERFACE=public
 export OS_IDENTITY_API_VERSION=3






