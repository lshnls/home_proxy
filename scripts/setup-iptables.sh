#!/bin/bash
# Скрипт для настройки iptables для прозрачного прокси

# Примечание: Этот скрипт должен быть запущен с привилегиями root

# IP контейнера Squid (замените на реальный IP)
SQUID_IP=""
DNS_PORT="53"
SQUID_PORT="3128"
SQUID_HTTP_PORT="8081"
SQUID_HTTPS_PORT="8082"

echo "Настройка iptables для прозрачного прокси..."

# Очистить существующие правила
iptables -t nat -F
iptables -t nat -X

# nat
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P INPUT ACCEPT
iptables -t nat -P OUTPUT ACCEPT
iptables -t nat -P POSTROUTING ACCEPT

# Перенаправить HTTP трафик на Squid
iptables -t nat -A PREROUTING ! -i lo -p tcp --dport 80 -j REDIRECT --to-port $SQUID_HTTP_PORT
# Перенаправить HTTPS трафик на Squid
iptables -t nat -A PREROUTING ! -i lo -p tcp --dport 443 -j REDIRECT --to-port $SQUID_HTTPS_PORT

# Разрешить локальный трафик
iptables -t nat -A OUTPUT ! -i lo -p tcp --dport 53 REDIRECT --to-port $DNS_PORT
iptables -t nat -A OUTPUT ! -i lo -p udp --dport 53 REDIRECT --to-port $DNS_PORT

# Разрешить исходящий трафик
iptables -t nat -A OUTPUT -o lo -j RETURN
iptables -t nat -A OUTPUT -d 192.168.0.0/16 -j RETURN
iptables -t nat -A OUTPUT -d 172.16.0.0/12 -j RETURN
iptables -t nat -A OUTPUT -d 10.0.0.0/8 -j RETURN
iptables -t nat -A OUTPUT -o home_proxy_tor -j RETURN
iptables -t nat -A OUTPUT -o home_proxy_squid -j RETURN
iptables -t nat -A OUTPUT -o home_proxy_unbound -j RETURN

# filter
iptables -t filter -P INPUT ACCEPT
iptables -t filter -P FORWARD DROP
iptables -t filter -P OUTPUT ACCEPT
iptables -t filter -A FORWARD -p udp --dport 443 -j DROP

echo "iptables настроены"
echo "HTTP трафик на портах 80 и 443 будет перенаправлен на прокси"



# *nat
# :PREROUTING ACCEPT [6:2126]
# :INPUT ACCEPT [0:0]
# :OUTPUT ACCEPT [17:6239]
# :POSTROUTING ACCEPT [6:408]

# -A PREROUTING ! -i lo -p tcp --dport 80 -j REDIRECT --to-port 8081
# -A PREROUTING ! -i lo -p tcp --dport 443 -j REDIRECT --to-port 8082
# -A PREROUTING ! -i lo -p tcp --dport 53 -j REDIRECT --to-ports 53
# -A PREROUTING ! -i lo -p udp --dport 53 -j REDIRECT --to-ports 53

# -A OUTPUT -o lo -j RETURN
# -A OUTPUT -d 192.168.1.0/24 -j RETURN
# -A OUTPUT -m owner --uid-owner "tor" -j RETURN


# COMMIT

# *filter
# :INPUT ACCEPT [0:0]
# :FORWARD DROP [0:0]
# :OUTPUT ACCEPT [0:0]

# # Блокируем QUIC
# -A FORWARD -p udp --dport 443 -j DROP

# COMMIT
