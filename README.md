# A Guide to set up a Sia Host behind a Proxy

Host at home with more security.

## Concept
`[Internet] -> [VPS reverse proxy with firewall] -> [Sia host]`  
`[Internet] <- [VPS forward proxy] <- [Sia host]`


## Reasons
### 🕵️ Hidden IP
When hosting on Sia, your IP will be public.  
And if this is your private IP, you might get DDoSed at home.  
This might result in the loss of your private internet, and believe me,
it sucks to have no internet for multiple days.

### 🔥 Configurable Firewall
Again, when hosting privately, you might suffer from a lack
of a firewall on your router.  
By using an extra Linux server, you can fully configure iptables, etc.

### 🥊 DDoS Resistance (Limited)
By using a VPS in a datacenter you can usually receive much more traffic
than by using a home server.  
This is why it is helpful to receive the traffic there, drop that bad traffic
and tunnel the good traffic to your sia host at home (theoretically).  
_This is really, really limited. If there is a real DDoS, you would are down._  
But, only your proxy VPS would go down, and not your Sia host / home network.


## Requirements and Conditions
This guide assumes hosting on a Linux machine.  
You also need a VPS (Debian is the most easy OS to handle).  
It might go done, so it should be dedicated for this purpose.  
It needs an IPv4 address and enough traffic.


## Guide
1. [Configure open ports of your home router](#Configure-open-ports-of-your-home-router)
2. [Configure reverse proxy](#Configure-reverse-proxy)
3. [Configure forward proxy SSH](#Configure-forward-proxy-SSH)
4. [Configure forward proxy proxychains](#Configure-forward-proxy-proxychains)
5. [Configure the firewall](#Configure-the-firewall)
6. [Start Sia](#Start-Sia)
7. [Autostart considerations](#Autostart-considerations)

### Configure open ports of your home router
You are here, so you probably know how to do this.  
Set up some open ports, that get redirected to your Sia host.  
I recommend using not the original `9981`-`9984` but higher ports like
`29981`-`29981`.  
Configure them to be redirected to `9981`-`9984` on your Sia host, or configure
the Sia host to listen to these new ports.

### Configure reverse proxy
We will use nginx as a reverse proxy.  
Install nginx.  
`sudo apt install nginx`

Edit the configuration.  
`sudo nano /etc/nginx/nginx.conf`  
The target ports depend on your choice from earlier.  
I continue to go with `29981`-`29981`.
Enter the following `stream` block above or under the `http` block.  

```conf
# /etc/nginx/nginx.conf
# [...]
stream {
        server {
                listen 9981;
                proxy_pass my.sia.at.home:29981;
        }
        server {
                listen 9982;
                proxy_pass my.sia.at.home:29982;
        }
        server {
                listen 9983;
                proxy_pass my.sia.at.home:29983;
        }
        server {
                listen 9984;
                proxy_pass my.sia.at.home:29984;
        }
}
# [...]
```
```bash
# Test whether your config is valid
nginx -t
# Reload config
sudo service nginx restart
```
You know a more elegant way than this? - Great! Open an issue or a pull request.


__Test the configuration__
```bash
# Run this on your Sia host
# Sia must be down for this one, so 9981 is free
nc -l 9981  # Change port if Sia should listen to another one
```
```bash
# Run this on your VPS
echo sending text to the sia server... | nc 127.0.0.1 9981
```
The text should appear on your Sia terminal running the `nc` command.

### Configure forward proxy SSH
We will use SSH as forward proxy.  
For this, ensure you can login onto your VPS via SSH without a password.

```bash
# Run this on your Sia host
# Skip this if you already have an SSH public key
ssh-keygen  # Press Enter until you are through

# Now copy the public key
cat ~/.ssh/id_rsa.pub
```
Create a SSH configuration entry on your Sia host.  
```
# On Sia host
# ~/.ssh/config

# Append this:
Host mysiaproxy
    User vps-username
    Port vps-ssh-port
    HostName vps.domain.tld.or.ip.address
```

Now you can SSH onto your proxy VPS by going `ssh mysiaproxy`.  
Next, append the public ssh key of the sia host to the file `~.ssh/authorized_keys` 
on your VPS.  
After having done that, you should be able to run `ssh mysiaproxy` on you sia host
without entering a password.  
Run `ssh mysiaproxy` on your Sia host. You should enter the shell without
requiring a password.

Run on your Sia host:  
```bash
ssh -TNfnqD 9999 mysiaproxy
```
[SSH command line parameters](https://www.ssh.com/academy/ssh/command)

This starts the forward proxy in the background.  
Validate that at least one `ssh` instace is running by calling `pidfof ssh`.

### Configure forward proxy proxychains
Install proxychains. This tool forces a process to use a internet proxy.
```bash
# Run this on your Sia host
sudo apt install proxychains
```

Edit the proxychains configuration:
```conf
# stuff

# Add the following line:
localnet 127.0.0.0/255.0.0.0

[ProxyList]
# Comment out the old proxy
# socks4 127.0.0.1 8050

# Add the following line:
socks4 127.0.0.1 9999  # port from ssh -D 9999
```


_Test configuration_  
```bash
# Run on your Sia host
proxychains curl https://api.ipify.org
# The printed IP should be the public IP of your VPS proxy
```

### Configure the firewall
This requires `iptables` on your VPS, which is usually installed by default.  
It might also conflict with `ufw` or `docker`.

```bash
# Run this on your proxy VPS
# Script from this git repo
bash firewall-ip-table-rules.sh
```

### Start Sia
```bash
# Run this on your Sia host

# Check if the proxy is still running
# This should print one integer if no other ssh session is running
pidof ssh

# Check if the proxy works
proxychains curl https://api.ipify.org
# The printed IP should be the public IP of your VPS proxy

# Start your Sia server
proxychains siad --your-parameters-as-usual
```
```bash
# Now you should be able to run siac
# After this, you have to wait until the announcement is in the blockchain
siac host announce vps.domain.tld.or.ip.address:9982
```

Check if everything is working on
https://troubleshoot.siacentral.com/sia/vps.domain.tld.or.ip.address:9982

### Autostart considerations
__VPS proxy__  
1. Nginx starts itself automatically
2. IP table rules clear themselves. Run `firewall-ip-table-rules.sh` after reboot

__Sia host__
1. Start the SSH proxy (`ssh -D mysiaproxy`) after reboot.
2. Siad should be configured to start with `proxychains`
