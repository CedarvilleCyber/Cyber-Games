# Networking
- **IMPORTANT**: IPs are examples, not actual topology
- `ip a` or `ifconfig` will show networking settings
- Settings will be different on different OSes
- Whitespace typically matters
## Kali
- File: `/etc/network/interfaces`
```
auto eth0
iface eth0 inet static
	address 192.168.118.100
	netmask 255.255.255.0
	gateway 192.168.118.1
```
- `systemctl restart networking`: required for changes to take effect
## Ubuntu
- Directory: `/etc/netplan/`
- File: `01-network-manager-all.yaml`
```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    ens18:
      addresses:
        - 192.168.118.2/24
      gateway4: 192.168.118.1
      nameservers:
        addresses:
          - 192.168.118.2
```
- White space is 2 spaces
- `netplan apply`
## CentOS/Rocky
- Directory: `/etc/sysconfig/network-scripts/`
- File exists for each interface (e.g. `/etc/sysconfig/network-scripts/ifcfg-eth0`)
- Basic structure of the file already exists, but some fields need added or changed
	- Changes
    - If the left is present, change it to the right
		- `BOOTPROTO=[dhcp/static]`
		- `ONBOOT=[no/yes]`
	- Additions
		- `IPADDR=172.20.118.1`
		- `NETMASK=255.255.0.0`
    - `GATEWAY=172.20.12.5`
- `systemctl restart network`
