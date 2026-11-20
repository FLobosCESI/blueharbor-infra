# Lab 03.4 — Hardening de WEB01

## Entorno

FreeBSD 15.1 sobre VMware Workstation Pro. Host WEB01, 10.10.20.20,
blueharbor.internal. Lynis 3.1.7.

## Línea base

`lynis audit system` con hardening_index=68, guardado en
/tmp/lynis-before.txt y /tmp/lynis-before.log.

## Cambios aplicados

| Área | Cambio | Fichero |
|---|---|---|
| Red | blackhole, syncookies, drop_synfin, drop_redirect, somaxconn, randompid, see_other_uids/gids, unprivileged_read_msgbuf | /etc/sysctl.conf |
| Resolución local | 10.10.20.20 WEB01.blueharbor.internal WEB01 | /etc/hosts |
| Umask | umask=027 en la clase default, cap_mkdb ejecutado | /etc/login.conf |
| Cuentas | pw lock toor, chmod 750 /home/opsadmin | /etc/master.passwd |
| Paquetes | pkg audit -F con base de vulnerabilidades descargada | — |
| Auditoría | accounting_enable=YES, /var/account/acct activo | /etc/rc.conf |
| Actualizaciones | freebsd-update cron, pkg audit -F -q, pkg upgrade -y | /etc/cron.d/freebsd-update |

## Antes y después

| Comprobación | Antes | Después |
|---|---|---|
| Hardening index | 68 | 74 |
| Accounting information (ACCT-2754) | NOT FOUND | OK |
| Permissions of home directories | WARNING | OK |
| net.inet.icmp.drop_redirect | DIFFERENT | OK |
| net.inet.ip.redirect | DIFFERENT | OK |
| net.inet.tcp.blackhole | DIFFERENT | OK |
| net.inet.tcp.drop_synfin | DIFFERENT | OK |
| net.inet.udp.blackhole | DIFFERENT | OK |
| PKGS-7381 | Sin base de datos | 3 paquetes vulnerables |
| Sugerencias | 15 | 12 |

## Puertos en escucha

| Puerto | Proto | Proceso | Justificación |
|---|---|---|---|
| 22 | tcp4/tcp6 | sshd | Administración desde 10.10.20.0/24, permitida por pf |
| 123 | udp4/udp6 | ntpd | Sincronización de hora |
| — | — | pf0 | Interfaz de pflog, PROMISC esperado |

## Desviaciones

- PKGS-7381: python312-3.12.16 (CVE-2025-15367, CVE-2025-15366),
  dbus-1.16.2_4,1 (CVE-2026-120749), py312-setuptools-63.1.0.3
  (CVE-2025-47273). No se remedian en este lab.
- Unreliable ntp peers pasó de NONE a FOUND tras habilitar accounting.
- NETW-3014: pf0 aparece en modo promiscuo; falso positivo, em0 y lo0
  no llevan la bandera.
- ntpd escucha en *:123; se deja abierto y se documenta.

## Conclusión

El índice subió de 68 a 74. Los controles de red, umask, cuentas y
auditoría quedaron en OK. Las desviaciones restantes son de parcheo de
paquetes y de configuración de ntpd.
