# Lab 04 · Exercise 4.4 · Virtual networks

## Modes compared

| Test | NAT Network BH-SRV (em0) | Segment LAN BH-STORAGE (em1) |
|---|---|---|
| VM to Internet (`fetch -o /dev/null https://example.com`) | exit=0, 577 B at 7408 kBps | not applicable |
| VM to VM (`ping 10.10.20.21` / `ping 172.16.30.21`) | 0.0% packet loss | 0.0% packet loss |
| Host to VM (`ping` from the laptop) | replies | 100% packet loss, no route |

## Measured results

- WEB01 172.16.30.20 to WEB02 172.16.30.21: 3 packets transmitted, 3 received, 0.0% packet loss, rtt min/avg/max/stddev 0.586/4.529/12.098/5.354 ms.
- WEB02 172.16.30.21 to WEB01 172.16.30.20: 3 packets transmitted, 3 received, 0.0% packet loss, rtt min/avg/max 0.662/0.771/0.953 ms.
- WEB01 10.10.20.20 to WEB02 10.10.20.21: 3 packets transmitted, 3 received, 0.0% packet loss, rtt min/avg/max/stddev 0.598/1.024/1.656/0.456 ms.
- Host to 172.16.30.21: 4 packets transmitted, 0 received, 100% packet loss; `route print` shows no route to 172.16.30.0/24 on the laptop.

## Interface inventory

| Host | Interface | Address | MAC | VMware device |
|---|---|---|---|---|
| WEB01 | em0 | 10.10.20.20/24 | 00:0c:29:99:01:52 | ethernet0, VMnet8 (NAT) |
| WEB01 | em1 | 172.16.30.20/24 | 00:0c:29:99:01:5c | ethernet1, pvn BH-STORAGE |
| WEB02 | em0 | 10.10.20.21/24 | 00:0c:29:9e:c0:72 | ethernet0, VMnet8 (NAT) |
| WEB02 | em1 | 172.16.30.21/24 | 00:0c:29:9e:c0:7c | ethernet1, pvn BH-STORAGE |

## Firewall

pf blocks everything by default (`block drop in log all`). ICMP is allowed per interface:

```
pass in on em0 inet proto icmp from 10.10.20.0/24 to any keep state
pass in on em1 inet proto icmp from 172.16.30.0/24 to any keep state
```

## Why storage traffic must not share the server network

The NFS and iSCSI traffic introduced in Lab 08 is bulk and latency sensitive. Sharing em0 with application traffic would make storage throughput compete with HTTP and SSH, and a saturated link would slow both. A dedicated segment keeps that traffic isolated, lets pf apply rules specific to the storage network instead of reusing the server rules, and limits what an attacker can reach if a web server is compromised: from WEB01 the storage segment is a separate broadcast domain with no route to the host.
