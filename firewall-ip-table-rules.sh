
### Drop UDP packets to the Sia ports
iptables -A INPUT -p udp --dport 9981 -j DROP
iptables -A INPUT -p udp --dport 9982 -j DROP
iptables -A INPUT -p udp --dport 9983 -j DROP
iptables -A INPUT -p udp --dport 9984 -j DROP

### Limit to 10 connections per second
iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 10 --connlimit-mask 32 -j DROP

# TODO More fancy IP table rules
