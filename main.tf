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
