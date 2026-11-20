# BlueHarbor — Dossier técnico

Documentación de la infraestructura del caso BlueHarbor (CESI International — 2026 Cloud Computing & DevOps).
Se actualiza al cierre de cada lab.

## Architecture

### Máquinas virtuales

| VM | Rol | Sistema | IP | Estado |
|---|---|---|---|---|
| DC01 | Controlador de dominio, DNS | Windows Server 2022 | 10.10.20.10 | Operativa |
| WEB01 | Servidor web y aplicación TrackIt | FreeBSD 15.1-RELEASE-amd64 | 10.10.20.20 | Operativa, endurecida |
| WEB02 | Servidor web secundario | FreeBSD 15.1-RELEASE-amd64 | — | Pendiente (Exercise 4.2) |

Dominio: `blueharbor.internal`. Hipervisor: VirtualBox sobre Windows.

### Red

NAT Network `BH-SRV`, 10.10.20.0/24, gateway 10.10.20.1.

Reenvíos de puertos definidos en `BH-SRV`:

| Regla | Puerto en el host | Destino |
|---|---|---|
| ssh-web01 | 127.0.0.1:2220 | 10.10.20.20:22 |
| ssh-web02 | 127.0.0.1:2221 | WEB02:22 |
| ssh-stor01 | — | STOR01:22 |

El puerto 2220 no existe en WEB01: es la regla de reenvío la que traduce 127.0.0.1:2220 a 10.10.20.20:22.

### Almacenamiento y particionado de WEB01

UFS sobre GPT, disco `ada0`:

| Partición | Punto de montaje | Tamaño |
|---|---|---|
| ada0p1 | EFI | 260M |
| ada0p2 | / | 24G |
| ada0p3 | swap | 1G |

`/home`, `/tmp` y `/var` viven dentro de `ada0p2`; no hay particiones separadas.

### Snapshots

| Snapshot | VM | UUID | Contenido |
|---|---|---|---|
| dc01-clean | DC01 | — | DC01 recién instalado y promovido |
| base-hardened | WEB01 | c05de4c6-c9f6-4beb-bf73-9308adbf79e1 | WEB01 tras el hardening del Lab 03 |

`base-hardened` es la base para el clon enlazado que crea WEB02 en el Exercise 4.2.

## Operations

### Acceso SSH a WEB01

Procedimiento para administrar WEB01 desde el portátil.

1. Abrir PuTTY con la sesión guardada `web01`: clave `web01.ppk`, puerto 2220, usuario `opsadmin`.
2. Ejecutar `su -` e introducir la contraseña de root para obtener la shell de root.
3. Alternativa desde Git Bash o PowerShell: `ssh web01`, que usa el alias de `~/.ssh/config` (HostName 127.0.0.1, Port 2220, User opsadmin, clave ed25519 sin contraseña).

Reglas activas en `/etc/ssh/sshd_config.d/10-hardening.conf`: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `MaxAuthTries 3`, `AllowGroups sudo`.

Si el acceso por clave falla, no se toca sshd a ciegas: se abre la consola de la VM en VirtualBox, se entra como `opsadmin` por consola y se revisan `/etc/ssh/sshd_config.d/10-hardening.conf` y los permisos de `~/.ssh/authorized_keys` (modo `600`, propietario `opsadmin`).

### Runbook del health check

Qué hace: `/usr/local/bin/bh-health.sh` se ejecuta cada 5 minutos desde `/etc/cron.d/bh-health` y escribe una línea por ejecución en `/var/log/bh-health.log` con marca de tiempo, host, load, memoria en porcentaje, disco en porcentaje y estado.

Umbrales: `status=WARN` si el disco llega al 80 % o la memoria al 90 %; en ese caso el script deja además una entrada con `logger -t bh-health`, que cae en `/var/log/messages` porque `syslogd_flags="-s"` está en `/etc/rc.conf`.

Comprobación rutinaria:

```sh
tail -n 5 /var/log/bh-health.log
grep WARN /var/log/bh-health.log | tail
grep bh-health /var/log/messages | tail
```

Si no aparecen líneas nuevas: comprobar que cron corre con `pgrep -l cron`, revisar `/etc/cron.d/bh-health` y lanzar el script a mano con `/usr/local/bin/bh-health.sh` seguido de `tail -1 /var/log/bh-health.log`.

Si el estado es WARN por disco: `df -h /` y `du -xh / --max-depth=2 | sort -h | tail`. Si es por memoria: `top -o res` y `vmstat 2`.

Crecimiento del log: una línea cada 5 minutos, 288 líneas al día.

### Hardening aplicado en WEB01

Cortafuegos: `pf` en lugar de UFW. `sysrc pf_enable=YES` y `sysrc pflog_enable=YES`, módulos cargados con `kldload pf` y `kldload pflog`, reglas en `/etc/pf.conf`.

Actualizaciones: `freebsd-update` ejecutado como root y actualización automática programada en `crontab`.

SSH: directivas en `/etc/ssh/sshd_config.d/10-hardening.conf`, sin login de root y sin autenticación por contraseña.

Sistema: `umask 027` en `/etc/login.conf` (`AUTH-9328`) y `/home/opsadmin` en modo 750 (`HOME-9304`).

Índice de hardening de Lynis: 60 antes, 66 después.

### Usuarios y permisos

`opsadmin` (uid 1001, grupos `opsadmin wheel`, shell `/bin/tcsh`), acceso por clave ed25519. `/srv/trackit` con grupo `webteam` y SGID 2775.

## Risks

### Hallazgos de Lynis no corregidos (Lab 03)

Segunda auditoría: índice de hardening 60 a 66. De las 26 sugerencias, se aplicaron `AUTH-9328` y `HOME-9304`. Las 24 restantes quedan abiertas con este motivo.

| ID | Hallazgo | Decisión | Motivo |
|---|---|---|---|
| AUTH-9218 | Cuenta con shell `/usr/local/libexec/uucp/uucico` inexistente | No corregido | Cuenta del sistema base; la shell no existe, así que no hay login posible. Deshabilitarla no reduce superficie remota y puede afectar a `freebsd-update`. |
| FILE-6310 | `/home` en partición separada | No corregido | WEB01 ya está instalada con UFS+GPT (`ada0p2` / 24G) y el snapshot `base-hardened` está tomado; reparticionar exige reinstalar. Mitigación: el health check avisa al 80 % de `/`. |
| FILE-6310 | `/tmp` en partición separada | No corregido | Igual que `/home`: `/tmp` vive en `ada0p2`. Se valora al reconstruir la VM en el Lab 04. |
| FILE-6310 | `/var` en partición separada | No corregido | Igual que `/home`: `/var` vive en `ada0p2`. |
| NAME-4028 | Comprobar la configuración DNS del dominio | No corregido | El dominio `blueharbor.internal` lo sirve DC01 en 10.10.20.10 y el search domain está configurado; Lynis no puede validarlo desde el host. Falso positivo en este entorno. |
| NAME-4404 | Añadir IP y FQDN a `/etc/hosts` | No corregido | Duplicaría la fuente de verdad: el registro A `web01` ya existe en la zona de DC01. Añadirlo enmascararía un fallo de DNS en las pruebas. |
| HTTP-6710 | HTTPS en los virtual hosts de nginx | No corregido | Requiere certificado y nombre válido; el lab no tiene CA. Se aborda cuando TrackIt se publique (Lab 06 y 07). |
| SSH-7408 | `AllowTcpForwarding`, `ClientAliveCountMax`, `LogLevel`, `MaxSessions`, `Port`, `TCPKeepAlive`, `UseDNS`, `AllowAgentForwarding` | No corregido | Criterio del Exercise 3.4: no tocar SSH en la misma sesión. El acceso ya está restringido a clave ed25519, sin password, sin root, `MaxAuthTries 3` y `AllowGroups sudo`. Cambiar `Port` rompería la regla `ssh-web01` (2220 a 22). Se revisan en el Lab 05. |
| LOGG-2154 | Logging a un host externo | No corregido | No existe colector todavía; el envío centralizado es el Exercise 7.5 con rsyslog en WEB01. |
| ACCT-2754 | Process accounting | No corregido | Escribe de forma continua en disco y el objetivo del lab es mantener `/` por debajo del 80 %; el workbook no pide auditoría de procesos. |
| TIME-3104 | NTP | No corregido | El desfase de una hora se corrigió a mano y la zona quedó en Europe/Paris. Habilitar ntpd requiere salida UDP/123 estable desde la NAT Network, que no está garantizada. |
| TOOL-5002 | Herramientas de automatización | No corregido | Falso positivo: Ansible se instala en el Lab 07. |
| FILE-7524 | Restringir permisos de ficheros | No corregido | El informe no da la lista concreta; aplicar `chmod` a ciegas sobre el sistema base puede romper servicios. La parte de homes se corrigió con `HOME-9304`. |
| HOME-9306 | Propiedad de los directorios personales | No corregido | Revisado a mano: `/home/opsadmin` es `opsadmin:opsadmin` y no hay otros homes. Sin hallazgo real. |
| KRNL-6000 | Valores sysctl distintos del perfil de Lynis | No corregido | Los valores de `/etc/sysctl.conf` son el baseline del lab; el perfil de Lynis propone claves que no aplican a FreeBSD 15.1 o que interfieren con pf. |
| HRDN-7222 | Restringir compiladores a root | No corregido | El sistema base incluye `cc` y restringirlo afecta a cualquier compilación futura; no hay puertos instalados que lo justifiquen. Se valora en el Lab 05. |
| HRDN-7230 | Instalar un escáner de malware | No corregido | Añade software no previsto en el workbook; la detección del lab se cubre con Suricata y fail2ban en el Lab 05. |
