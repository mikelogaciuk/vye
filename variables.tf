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
