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

In my case, my PC has 16vCPUs & 48GB of RAM, but to sustain host operability. I will limit its resources to 14 vCPUs and 40 GB of RAM.

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
        sudo apt install btop
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
        echo enable_plugin barbican https://opendev.org/openstack/barbican >> local.conf
        echo enable_plugin mistral https://github.com/openstack/mistral >> local.conf
        echo enable_plugin senlin https://git.openstack.org/openstack/senlin >> local.conf
        echo enable_plugin senlin-dashboard https://git.openstack.org/openstack/senlin-dashboard >> local.conf
        echo enable_plugin heat https://git.openstack.org/openstack/heat >> local.conf
        echo enable_plugin sahara https://opendev.org/openstack/sahara >> local.conf
        echo enable_plugin trove https://opendev.org/openstack/trove >> local.conf
        echo enable_plugin trove-dashboard https://opendev.org/openstack/trove-dashboard >> local.conf
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
  default = 14
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

## Run the machine

To run the machine type:

```bash
$ terraform init
$ terraform apply --auto-aprove

Plan: 3 to add, 0 to change, 0 to destroy.
libvirt_volume.distro-qcow2[0]: Creating...
libvirt_cloudinit_disk.commoninit[0]: Creating...
libvirt_volume.distro-qcow2[0]: Creation complete after 1s [id=/home/runner/repos/vye/volumes/ubuntu.qcow2]
libvirt_cloudinit_disk.commoninit[0]: Creation complete after 1s [id=/home/runner/repos/vye/volumes/commoninit-ubuntu.iso;0a9296a6-2cd2-4a1f-b595-726a63cc81a5]
libvirt_domain.domain-distro[0]: Creating...
libvirt_domain.domain-distro[0]: Creation complete after 0s [id=1c98a9be-0554-47fb-a98d-65b54a6f93ae]
```

## Connect

In order to connect to the VM, type:

```bash
ssh vye@192.168.122.11
```

Or far more pleasant (at least for me):

```bash
ssh -t vye@192.168.122.11 bash -l
```

Then you should be able to operate on your newly created host.

## Cloud-init

The setup should take about 30 minutes. In order to watch the process live in the console, you can type:

```bash
watch 'sudo tail -30 /var/log/cloud-init-output.log'
```

Once it's complete, you should see something like this once you type:

```bash
$ sudo tail -30 /var/log/cloud-init-output.log

This is your host IP address: 192.168.122.11
This is your host IPv6 address: ::1
Horizon is now available at http://192.168.122.11/dashboard
Keystone is serving at http://192.168.122.11/identity/
The default users are: admin and demo
The password: MYSECRET@PWD

Services are running under systemd unit files.
For more information see:
https://docs.openstack.org/devstack/latest/systemd.html

DevStack Version: 2023.2
Change: e261bd809e81c01c153cdcdb50be47ed3c89c46a Always set image_uuid_alt in configure_tempest() 2023-07-19 16:04:12 -0400
OS Version: Ubuntu 22.04 jammy

2023-07-20 23:05:34.163 | stack.sh completed in 662 seconds.
Cloud-init v. 23.2.1-0ubuntu0~22.04.1 finished at Thu, 20 Jul 2023 23:05:34 +0000. Datasource DataSourceNoCloud [seed=/dev/sr0][dsmode=net].  Up 696.32 second
```

## Dashboard

In order to open a dashboard, click this [http://192.168.122.11/dashboard/project/](http://192.168.122.11/dashboard/project/).

You should see something like this:

![OpenStackUI](https://cdn.hashnode.com/res/hashnode/image/upload/v1689895339349/f11f37e6-8c9a-4179-bd03-1dcb3b7791a2.png)

CLI

In order to install `OpenStack CLI` type:

```bash
$ sudo apt install python3-openstackclient
```

Next, navigate to the dashboard and click at `Project / Api Access` and then press **Download OpenStack RC File.**

Once you download file, type:

```bash
cd ~/Downloads
source admin-openrc.sh
```

Now you should be able to operate using CLI:

```bash
$ openstack catalog list

+-------------+-----------------+------------------------------------------------------------------------------+
| Name        | Type            | Endpoints                                                                    |
+-------------+-----------------+------------------------------------------------------------------------------+
| nova        | compute         | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/compute/v2.1                                 |
|             |                 |                                                                              |
| cinder      | block-storage   | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/volume/v3/af2479122d5343b3896dbc6693ebab4b   |
|             |                 |                                                                              |
| nova_legacy | compute_legacy  | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/compute/v2/af2479122d5343b3896dbc6693ebab4b  |
|             |                 |                                                                              |
| heat-cfn    | cloudformation  | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/heat-api-cfn/v1                              |
|             |                 |                                                                              |
| heat        | orchestration   | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/heat-api/v1/af2479122d5343b3896dbc6693ebab4b |
|             |                 |                                                                              |
| senlin      | clustering      | RegionOne                                                                    |
|             |                 |   internal: http://192.168.122.11/cluster                                    |
|             |                 | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/cluster                                      |
|             |                 | RegionOne                                                                    |
|             |                 |   admin: http://192.168.122.11/cluster                                       |
|             |                 |                                                                              |
| neutron     | network         | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11:9696/networking                              |
|             |                 |                                                                              |
| sahara      | data-processing | RegionOne                                                                    |
|             |                 |   admin: http://192.168.122.11:8386                                          |
|             |                 | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11:8386                                         |
|             |                 | RegionOne                                                                    |
|             |                 |   internal: http://192.168.122.11:8386                                       |
|             |                 |                                                                              |
| mistral     | workflowv2      | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11:8989/v2                                      |
|             |                 | RegionOne                                                                    |
|             |                 |   admin: http://192.168.122.11:8989/v2                                       |
|             |                 | RegionOne                                                                    |
|             |                 |   internal: http://192.168.122.11:8989/v2                                    |
|             |                 |                                                                              |
| keystone    | identity        | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/identity                                     |
|             |                 |                                                                              |
| placement   | placement       | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/placement                                    |
|             |                 |                                                                              |
| ec2         | ec2             | RegionOne                                                                    |
|             |                 |   internal: http://192.168.122.11:8788/                                      |
|             |                 | RegionOne                                                                    |
|             |                 |   admin: http://192.168.122.11:8788/                                         |
|             |                 | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11:8788/                                        |
|             |                 |                                                                              |
| trove       | database        | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11:8779/v1.0/af2479122d5343b3896dbc6693ebab4b   |
|             |                 | RegionOne                                                                    |
|             |                 |   internal: http://192.168.122.11:8779/v1.0/af2479122d5343b3896dbc6693ebab4b |
|             |                 | RegionOne                                                                    |
|             |                 |   admin: http://192.168.122.11:8779/v1.0/af2479122d5343b3896dbc6693ebab4b    |
|             |                 |                                                                              |
| s3          | s3              | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11:3334/                                        |
|             |                 | RegionOne                                                                    |
|             |                 |   internal: http://192.168.122.11:3334/                                      |
|             |                 | RegionOne                                                                    |
|             |                 |   admin: http://192.168.122.11:3334/                                         |
|             |                 |                                                                              |
| glance      | image           | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/image                                        |
|             |                 |                                                                              |
| cinderv3    | volumev3        | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/volume/v3/af2479122d5343b3896dbc6693ebab4b   |
|             |                 |                                                                              |
| barbican    | key-manager     | RegionOne                                                                    |
|             |                 |   internal: http://192.168.122.11/key-manager                                |
|             |                 | RegionOne                                                                    |
|             |                 |   admin: http://192.168.122.11/key-manager                                   |
|             |                 | RegionOne                                                                    |
|             |                 |   public: http://192.168.122.11/key-manager                                  |
|             |                 |                                                                              |
+-------------+-----------------+------------------------------------------------------------------------------+
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

Plan: 0 to add, 0 to change, 3 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

libvirt_domain.domain-distro[0]: Destroying... [id=0eb6ad1f-b42b-4fd9-949f-175e3868e7db]
libvirt_domain.domain-distro[0]: Destruction complete after 0s
libvirt_cloudinit_disk.commoninit[0]: Destroying... [id=/home/runner/repos/vye/volumes/commoninit-ubuntu.iso;129dd9d9-c055-4366-aae0-530b2badc23a]
libvirt_volume.distro-qcow2[0]: Destroying... [id=/home/runner/repos/vye/volumes/ubuntu.qcow2]
libvirt_cloudinit_disk.commoninit[0]: Destruction complete after 0s
libvirt_volume.distro-qcow2[0]: Destruction complete after 0s
```

To remove SSH known host, type:

```bash
$ ssh-keygen -f "$HOME/.ssh/known_hosts" -R "192.168.122.11"
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

