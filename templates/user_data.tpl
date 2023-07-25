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
