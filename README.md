# vye

![vye](./img/vye_4.png)

## About

`Vye` is a codename for home-cloud `Terraform` deployment model, described as a side project in an article [Why my GitHub profile is empty?](https://mlog.hashnode.dev/why-my-github-profile-is-empty).

It is a virtual machine that comes with Ubuntu Server and OpenStack installed used to mimic a true private cloud environment. Originally hosted as a VM on PC with: 16 vCPUs and 48GB of RAM, but in order to sustain host operability - it is set to use 12 vCPUs and 40GBs of RAM.

## Name origin

`Vye` is a short and catchy name that is derived from the word `"vie,"` which means to compete eagerly or strive for superiority.

The name is relevant to the business description as it conveys the idea of competitiveness and striving for excellence, which is essential in the software development and DevOps industry. Additionally, the name's brevity and simplicity make it easy to remember and brandable, which is crucial for a business that offers home cloud software and private DevOps services.

Overall, Vye is a strong and fitting name that effectively communicates the company's values and services.

## History

OpenStack is an open-source cloud platform that manages distributed compute, network, and storage resources, aggregates them into pools, and allows on-demand provisioning of virtual resources through a self-service portal. It is the most widely deployed open-source cloud software in the world, deployed by thousands and proven production at scale.

OpenStack is developed by the community for the community and provides common services for cloud infrastructure. It controls large pools of compute, storage, and networking resources, all managed through APIs or a dashboard.

[Beyond standard infrastructure-as-a-service functionality, additional components provide orchestration, fault management, and service management amongst other services to ensure high availability of user applications](https://www.openstack.org/).

## And so what?

Having your private cloud to get into it without having to pay for compute resources in AWS/AKS is quite tempting, isn't it?

Having stuff like OpenStack allows us to practice cloud management right in our bare-metal hardware.

For the sake of this **Proof of Concept** we will developer version of the official **OpenStack**.

## What for?

For some of you. you probably wonder what can you practice, but believe me: there are tons of ideas to implement.

From typical single virtual machines that do something to heavier workloads with three-node Kubernetes clusters altogether with additional services/servers on separate machines.

## Preparations

First, we need a virtual machine that will do the stuff for us - but for this, we will need **QEMU**, **KVM** and **Terraform**.

Instructions on how to install them can be found [here](https://hashnode.com/post/cljrmc4ed000209mlhxjk3k0y).

In my case, my PC has 16vCPUs & 48GB of RAM, but to sustain host operability. I will limit its resources to 12 vCPUs and 40 GB of RAM.

## Manual setup

### Directory

First, we create a fresh directory:

```bash
mkdir -p ~/repos/vye
```

Next, we create a directory called `sources`, `templates` and `ssh`:

```bash
cd ~/repos/vye
mkdir -p sources templates volumes ssh
```

### Sources

Now we need to have a source for our server. The simplest way is to download an image for the cloud hosted by Ubuntu creators and use it as our source:

```bash
wget -O ubuntu.qcow2 https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
qemu-img resize sources/ubuntu.qcow2 100G
```

Explanation: First we downloaded the cloud image, then we resized it for further usage.

### SSH

Generate a new key pair using the RSA algorithm if no key pair exists:

```bash
ssh-keygen -t rsa -b 4096 -f $HOME/.ssh/id_rsa -N ""
ln -s $HOME/.ssh/id_rsa.pub $HOME/repos/vye/ssh/
```

If you encounter permission problems, set set `security_driver = "none"` in `/etc/libvirt/qemu.conf` and restart the service using:

```bash
sudo service libvirtd restart
```

### Storage pool

Create a folder with the name `volumes` under the project root directory to host the new pool:

```bash
$ sudo mkdir $HOME/terraform/volumes
```

Next type `virsh` and:

```bash
$ pool-define-as --name vye --type dir --target $HOME/repos/vye/volumes
$ pool-autostart vye
$ pool-start vye

$ pool-list
Name                 State      Autostart
-------------------------------------------
vye                  active     yes
```

### Templates

Next move to `templates` directory and create two files:

```bash
touch templates/user_data.tpl templates/network_config.tpl
```

### User data

This is the main part of our cloud-init part that installs our `DevStack` automatically into our VM:

```yaml
#cloud-config
# vim: syntax=yaml
hostname: ${host_name}
manage_etc_hosts: true
users:
  - name: vye
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${auth_key}
  - name: stack
    lock_passwd: False
    sudo: ["ALL=(ALL) NOPASSWD:ALL\nDefaults:stack !requiretty"]
    shell: /bin/bash
ssh_pwauth: true
disable_root: false
chpasswd:
  list: |
    vye:linux
  expire: false
growpart:
  mode: auto
  devices: ['/']
write_files:
  - content: |
        #!/bin/sh
        DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update || sudo yum update -qy
        DEBIAN_FRONTEND=noninteractive sudo apt-get install -qqy git || sudo yum install -qy git
        sudo chown stack:stack /home/stack
        cd /home/stack
        git clone https://opendev.org/openstack/devstack
        cd devstack
        echo '[[local|localrc]]' > local.conf
        echo ADMIN_PASSWORD=${api_key} >> local.conf
        echo DATABASE_PASSWORD=${api_key} >> local.conf
        echo RABBIT_PASSWORD=${api_key} >> local.conf
        echo SERVICE_PASSWORD=${api_key} >> local.conf
        echo enable_plugin ec2-api https://opendev.org/openstack/ec2-api >> local.conf
        ./stack.sh
    path: /home/stack/start.sh
    permissions: 0755

runcmd:
  - su -l stack ./start.sh
```

### API Key

Normally, passwords etc are stored as environment variables or in vaults, so for PoC purposes you need to export a variable called `TF_VAR_dev_stack_api_key`.

You can change its name and value to whatever you want to:

```bash
$ echo 'MYSECRET@PWD' | base64
TVlTRUNSRVRAUFdECg==
```

```bash
$ export TF_VAR_dev_stack_api_key=$(eval echo TVlTRUNSRVRAUFdECg== | base64 --decode)
```

### Network template

```yaml
ethernets:
    ${interface}:
        addresses:
        - ${ip_addr}/24
        dhcp4: false
        gateway4: 192.168.122.1
        match:
            macaddress: ${mac_addr}
        nameservers:
            addresses:
            - 1.1.1.1
            - 8.8.8.8
        set-name: ${interface}
version: 2
```

### Terraform

Create two files, `main.tf` and `variables.tf`:

```yaml
touch main.tf variables.tfg
```

Next, add the code below to specific files.

### Variables

```ini
variable "hosts" {
  type    = number
  default = 1
}
variable "interface" {
  type    = string
  default = "ens01"
}
variable "memory" {
  type    = string
  default = "40960"
}
variable "vcpu" {
  type    = number
  default = 12
}
variable "distros" {
  type    = list(any)
  default = ["ubuntu"]
}
variable "hostnames" {
  type    = list(any)
  default = ["vye"]
}
variable "ips" {
  type    = list(any)
  default = ["192.168.122.11"]
}
variable "macs" {
  type    = list(any)
  default = ["52:54:00:0e:87:be"]
}
variable "dev_stack_api_key" {
  type = string
}
```

### Main

```ini
terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}
provider "libvirt" {
  uri = "qemu:///system"
}
resource "libvirt_volume" "distro-qcow2" {
  count  = var.hosts
  name   = "${var.distros[count.index]}.qcow2"
  pool   = "vye"
  source = "${path.module}/sources/${var.distros[count.index]}.qcow2"
  format = "qcow2"
}
resource "libvirt_cloudinit_disk" "commoninit" {
  count = var.hosts
  name  = "commoninit-${var.distros[count.index]}.iso"
  pool  = "vye"
  user_data = templatefile("${path.module}/templates/user_data.tpl", {
    host_name = var.distros[count.index]
    auth_key  = file("${path.module}/ssh/id_rsa.pub")
    api_key   = var.dev_stack_api_key
  })
  network_config = templatefile("${path.module}/templates/network_config.tpl", {
    interface = var.interface
    ip_addr   = var.ips[count.index]
    mac_addr  = var.macs[count.index]
  })
}
resource "libvirt_domain" "domain-distro" {
  count     = var.hosts
  name      = var.hostnames[count.index]
  memory    = var.memory
  vcpu      = var.vcpu
  cpu {
    mode = "host-passthrough"
  }
  cloudinit = element(libvirt_cloudinit_disk.commoninit.*.id, count.index)

  network_interface {
    network_name = "default"
    addresses    = [var.ips[count.index]]
    mac          = var.macs[count.index]
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_port = "1"
    target_type = "virtio"
  }
  disk {
    volume_id = element(libvirt_volume.distro-qcow2.*.id, count.index)
  }
}
```

### Run the machine

To run the machine type:

```bash
$ terraform init
$ terraform apply --auto-aprove
```

### Connect

In order to connect to the VM, type:

```bash
ssh vye@192.168.122.11
```

Then you should be able to operate on your newly created host:

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1689887529894/39bcf5d5-7e1d-485f-a91c-498904c0b0d7.png align="center")

### Cloud-init

After 10 minutes or so, you should see something like this once you type:

```bash
$ sudo tail -100 /var/log/cloud-init-output.log

+ ./stack.sh:main:1517                     :   set +o xtrace

=========================
DevStack Component Timing
 (times are in seconds)
=========================
wait_for_service       6
async_wait            67
osc                   80
apt-get              163
test_with_retry        2
dbsync                 4
pip_install           97
apt-get-update         0
run_process            9
git_timed            160
-------------------------
Unaccounted time      74
=========================
Total runtime        662

=================
 Async summary
=================
 Time spent in the background minus waits: 165 sec
 Elapsed time: 662 sec
 Time if we did everything serially: 827 sec
 Speedup:  1.24924


Post-stack database query stats:
+------------+-----------+-------+
| db         | op        | count |
+------------+-----------+-------+
| keystone   | SELECT    | 41516 |
| keystone   | INSERT    |    96 |
| glance     | SELECT    |  1002 |
| glance     | CREATE    |    65 |
| glance     | INSERT    |   254 |
| glance     | SHOW      |     8 |
| glance     | UPDATE    |    17 |
| glance     | ALTER     |     9 |
| glance     | DROP      |     1 |
| cinder     | SELECT    |   148 |
| cinder     | CREATE    |    74 |
| cinder     | SET       |     1 |
| cinder     | ALTER     |    21 |
| neutron    | SELECT    |  4880 |
| neutron    | SHOW      |    45 |
| neutron    | CREATE    |   317 |
| neutron    | INSERT    |  1190 |
| neutron    | UPDATE    |   222 |
| neutron    | ALTER     |   191 |
| neutron    | DROP      |    53 |
| neutron    | DELETE    |    25 |
| nova_cell1 | SELECT    |   146 |
| nova_cell1 | CREATE    |   211 |
| nova_cell0 | SELECT    |   160 |
| nova_cell0 | CREATE    |   211 |
| nova_cell1 | ALTER     |     3 |
| nova_cell1 | SHOW      |    59 |
| nova_cell0 | ALTER     |     3 |
| nova_cell0 | SHOW      |    59 |
| nova_cell1 | INSERT    |     6 |
| nova_cell0 | INSERT    |     9 |
| placement  | SELECT    |    35 |
| placement  | INSERT    |    57 |
| placement  | SET       |     3 |
| nova_api   | SELECT    |    98 |
| placement  | UPDATE    |     3 |
| cinder     | INSERT    |     5 |
| nova_cell1 | UPDATE    |     7 |
| cinder     | UPDATE    |     6 |
| nova_cell0 | UPDATE    |    18 |
| nova_api   | SAVEPOINT |    10 |
| nova_api   | INSERT    |    15 |
| nova_api   | RELEASE   |    10 |
| cinder     | DELETE    |     1 |
| keystone   | DELETE    |     1 |
+------------+-----------+-------+



This is your host IP address: 192.168.122.11
This is your host IPv6 address: ::1
Horizon is now available at http://192.168.122.11/dashboard
Keystone is serving at http://192.168.122.11/identity/
The default users are: admin and demo
The password: mycloudpwd

Services are running under systemd unit files.
For more information see:
https://docs.openstack.org/devstack/latest/systemd.html

DevStack Version: 2023.2
Change: e261bd809e81c01c153cdcdb50be47ed3c89c46a Always set image_uuid_alt in configure_tempest() 2023-07-19 16:04:12 -0400
OS Version: Ubuntu 22.04 jammy

2023-07-20 23:05:34.163 | stack.sh completed in 662 seconds.
Cloud-init v. 23.2.1-0ubuntu0~22.04.1 finished at Thu, 20 Jul 2023 23:05:34 +0000. Datasource DataSourceNoCloud [seed=/dev/sr0][dsmode=net].  Up 696.32 second
```

### Dashboard

In order to open a dashboard, click this [http://192.168.122.11/dashboard/project/](http://192.168.122.11/dashboard/project/).

You should see something like this:

![](https://cdn.hashnode.com/res/hashnode/image/upload/v1689895339349/f11f37e6-8c9a-4179-bd03-1dcb3b7791a2.png align="center")

CLI

In order to install `OpenStack CLI` type:

```bash
$ sudo apt install python3-openstackclient
```

Next, navigate to dashboard and click at `Project / Api Access` and then press **Download OpenStack RC File.**

Once you download file, type:

```bash
cd ~/Downloads
source admin-openrc.sh
```

Now you should be able to operate using CLI:

```bash
$ openstack catalog list

+-------------+----------------+-----------------------------------------------------------------------------+
| Name        | Type           | Endpoints                                                                   |
+-------------+----------------+-----------------------------------------------------------------------------+
| cinderv3    | volumev3       | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11/volume/v3/c1f273a25e4740c486cc58c2433326d5  |
|             |                |                                                                             |
| cinder      | block-storage  | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11/volume/v3/c1f273a25e4740c486cc58c2433326d5  |
|             |                |                                                                             |
| nova        | compute        | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11/compute/v2.1                                |
|             |                |                                                                             |
| glance      | image          | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11/image                                       |
|             |                |                                                                             |
| nova_legacy | compute_legacy | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11/compute/v2/c1f273a25e4740c486cc58c2433326d5 |
|             |                |                                                                             |
| keystone    | identity       | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11/identity                                    |
|             |                |                                                                             |
| placement   | placement      | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11/placement                                   |
|             |                |                                                                             |
| neutron     | network        | RegionOne                                                                   |
|             |                |   public: http://192.168.122.11:9696/networking                             |
|             |                |                                                                             |
+-------------+----------------+-----------------------------------------------------------------------------+
```

```bash
$ openstack flavor list
+----+-----------+-------+------+-----------+-------+-----------+
| ID | Name      |   RAM | Disk | Ephemeral | VCPUs | Is Public |
+----+-----------+-------+------+-----------+-------+-----------+
| 1  | m1.tiny   |   512 |    1 |         0 |     1 | True      |
| 2  | m1.small  |  2048 |   20 |         0 |     1 | True      |
| 3  | m1.medium |  4096 |   40 |         0 |     2 | True      |
| 4  | m1.large  |  8192 |   80 |         0 |     4 | True      |
| 42 | m1.nano   |   128 |    1 |         0 |     1 | True      |
| 5  | m1.xlarge | 16384 |  160 |         0 |     8 | True      |
| 84 | m1.micro  |   192 |    1 |         0 |     1 | True      |
| c1 | cirros256 |   256 |    1 |         0 |     1 | True      |
| d1 | ds512M    |   512 |    5 |         0 |     1 | True      |
| d2 | ds1G      |  1024 |   10 |         0 |     1 | True      |
| d3 | ds2G      |  2048 |   10 |         0 |     2 | True      |
| d4 | ds4G      |  4096 |   20 |         0 |     4 | True      |
+----+-----------+-------+------+-----------+-------+-----------+
```

## Teardown

In order to destroy machine (volumes), type:

```bash
$ terraform destroy
```

**Note**: *This will destroy your all current work.*

## Courses, tips

* **Cannonical** has a great introduction to OpenStack and it can be found [**here**](https://ubuntu.com/openstack/tutorials).

* **FreeCodeCamp** has also another great tutorial which can be found [**here**](https://www.freecodecamp.org/news/openstack-tutorial-operate-your-own-private-cloud/).

* Official **DevStack** docs can be found [**here**](https://docs.openstack.org/devstack/latest/guides/single-vm.html).


## References

1. DevStack @ [Cloud-Init](https://docs.openstack.org/devstack/latest/guides/single-vm.html)

2. Terraform Registry @ [dmacvicar/libvirt](https://registry.terraform.io/providers/dmacvicar/libvirt/latest)

3. Fabian Lee @ [**KVM: Terraform and cloud-init to create local KVM resources**](https://fabianlee.org/2020/02/22/kvm-terraform-and-cloud-init-to-create-local-kvm-resources/)

4. Yu Ping @ [**Provisioning Multiple Linux Distributions using Terraform Provider for Libvirt**](https://yping88.medium.com/provisioning-multiple-linux-distributions-using-terraform-provider-for-libvirt-632186f1c007)

5. Harshavardhan Katkam @ [**Best practices for writing Terraform code**](https://awstip.com/best-practices-for-writing-terraform-code-852aad68caa1)
