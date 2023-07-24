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
