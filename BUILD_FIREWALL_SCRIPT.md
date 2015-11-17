# Firewall

SpineOS firewall script is built from `Easy Firewall Generator for IPTables` version 1.17. This program is available [here](http://www.slackware.com/~alien/efg/index.php).

## Settings

These are the options to select for generating the script.

<pre>
Internet Interface:  eth0

<b>Select Type of Internet Address</b>
√ Dynamic Internet IP Address

<b>Single System or Private Network Gateway?</b>
√ Gateway/Firewall

  a. Internal Network Interface:   br0
  b. Internal Network IP Address:  192.168.1.1
  c. Internal Network:             192.168.1.0/24
  d. Internal Network Broadcast:   192.168.1.255

<b>√ Advanced Network Options</b>
√ Internal DHCP Server
√ Enable Port Forwarding to an Internal System
  Port: 80    TCP
  Internal IP: 192.168.98.1

<b>√ Allow Inbound Services</b>
√ SSH
√ Time Server (NTP)

<b>√ Log entries in a Fireparse format?</b>
<b>√ Do you use Internet Relay Chat (IRC)?</b>

</pre>

The generated script becomes `rc.firewall`.


## Customization

Before being usable `rc.firewall` requires the following changes:

Around the line `666` below the text:

```
# Port Forwarding is enabled, so accept forwarded traffic
```

remove the iptable rule and replace it by the tag:
```
#@forward@#
```


Then, in the `PREROUTING chain` section, replace the rule:

```
$IPT -t nat -A PREROUTING -p tcp -i $INET_IFACE --destination-port 80 \
     -j DNAT --to-destination 192.168.98.1
```

by the tag:

```
#@prerouting@#
```

That's all!
