# vye

![vye](./img/vye_4.png)

## About

`Vye` is a codename for home-cloud `Terraform` deployment model, described as a side project in an article [Why my GitHub profile is empty?](https://mlog.hashnode.dev/why-my-github-profile-is-empty).

It is a virtual machine that comes with Ubuntu Server and OpenStack installed used to mimic a true private cloud environment. Originally hosted as a VM on PC with: 16 vCPUs and 48GB of RAM, but in order to sustain host operability - it is set to use 12 vCPUs and 40GBs of RAM.

## Name origin

`Vye` is a short and catchy name that is derived from the word `"vie,"` which means to compete eagerly or strive for superiority.

The name is relevant to the business description as it conveys the idea of competitiveness and striving for excellence, which is essential in the software development and DevOps industry. Additionally, the name's brevity and simplicity make it easy to remember and brandable, which is crucial for a business that offers home cloud software and private DevOps services.

Overall, Vye is a strong and fitting name that effectively communicates the company's values and services.

## Setup

Whole Terraform setup procedure can be found in the article [OpenStack: Getting started with private cloud](https://mlog.hashnode.dev/openstack-getting-started-with-private-cloud).

## Outro

After doing everything as in tutorial, you should be able to see in your console - this:

```bash
openstack flavor list
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
