# Очистить
sudo iptables -t nat -N SQUID_LAN 2>/dev/null || true
sudo iptables -t nat -F SQUID_LAN

sudo iptables -t nat -A SQUID_LAN -d 0.0.0.0/8 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 10.0.0.0/8 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 127.0.0.0/8 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 169.254.0.0/16 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 172.16.0.0/12 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 192.168.0.0/16 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 224.0.0.0/4 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 240.0.0.0/4 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 172.17.0.0/16 -j RETURN
sudo iptables -t nat -A SQUID_LAN -d 172.18.0.0/16 -j RETURN

sudo iptables -t nat -A SQUID_LAN -s 192.168.100.0/24 -p tcp --dport 80 -j REDIRECT --to-ports 8081
sudo iptables -t nat -A SQUID_LAN -s 192.168.100.0/24 -p tcp --dport 443 -j REDIRECT --to-ports 8082

sudo iptables -t nat -D PREROUTING -s 192.168.100.0/24 -p tcp -j SQUID_LAN 2>/dev/null || true
sudo iptables -t nat -I PREROUTING 1 -s 192.168.100.0/24 -p tcp -j SQUID_LAN

