#!/bin/bash
#
# Объявление переменных
export IPT="iptables"

# Интерфейс который смотрит в интернет
export WAN=eth0
export WAN_IP=185.92.74.136

# Очистка всех цепочек iptables
$IPT -F
$IPT -F -t nat
$IPT -F -t mangle
$IPT -X
$IPT -t nat -X
$IPT -t mangle -X

# Установим политики по умолчанию для трафика, не соответствующего ни одному из правил
$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP

# разрешаем локальный траффик для loopback
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

# Разрешаем исходящие соединения самого сервера
$IPT -A OUTPUT -o $WAN -j ACCEPT

# Состояние ESTABLISHED говорит о том, что это не первый пакет в соединении.
# Пропускать все уже инициированные соединения, а также дочерние от них
$IPT -A INPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT
# Пропускать новые, а так же уже инициированные и их дочерние соединения
$IPT -A OUTPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT
# Разрешить форвардинг для уже инициированных и их дочерних соединений
$IPT -A FORWARD -p all -m state --state ESTABLISHED,RELATED -j ACCEPT

# Включаем фрагментацию пакетов. Необходимо из за разных значений MTU
$IPT -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Отбрасывать все пакеты, которые не могут быть идентифицированы
# и поэтому не могут иметь определенного статуса.
$IPT -A INPUT -m state --state INVALID -j DROP
$IPT -A FORWARD -m state --state INVALID -j DROP

# Блокируем нулевые пакеты
$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Приводит к связыванию системных ресурсов, так что реальный
# обмен данными становится не возможным, обрубаем
$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
$IPT -A OUTPUT -p tcp ! --syn -m state --state NEW -j DROP

# Рзрешаем пинги
#$IPT -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
#$IPT -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
#$IPT -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
#$IPT -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Открываем порт для ssh
$IPT -A INPUT -i $WAN -p tcp --dport 22888 -j ACCEPT
# Открываем порт для http
#$IPT -A INPUT -i $WAN -p tcp --dport 80 -j ACCEPT
# Открываем порт для https
#$IPT -A INPUT -i $WAN -p tcp --dport 443 -j ACCEPT
# Открываем порт для openvpn
$IPT -A INPUT -i $WAN -p tcp --dport 9996 -j ACCEPT

# Разрешим интерфейсу tun коммуникацию с другими интерфейсами в системе
$IPT -A FORWARD -i tun+ -j ACCEPT
$IPT -A FORWARD -i tun+ -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPT -A FORWARD -i eth0 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# Включим nat
$IPT -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Разрешить исходящий трафик на tun-инмерфейсе
$IPT -A OUTPUT -o tun+ -j ACCEPT

# Логирование
# Все что не разрешено, но ломится отправим в цепочку undef

#$IPT -N undef_in
#$IPT -N undef_out
#$IPT -N undef_fw
#$IPT -A INPUT -j undef_in
#$IPT -A OUTPUT -j undef_out
#$IPT -A FORWARD -j undef_fw

# Логируем все из undef

#$IPT -A undef_in -j LOG --log-level info --log-prefix "-- IN -- DROP "
#$IPT -A undef_in -j DROP
#$IPT -A undef_out -j LOG --log-level info --log-prefix "-- OUT -- DROP "
#$IPT -A undef_out -j DROP
#$IPT -A undef_fw -j LOG --log-level info --log-prefix "-- FW -- DROP "
#$IPT -A undef_fw -j DROP

# Записываем правила
/sbin/iptables-save  > /etc/sysconfig/iptables