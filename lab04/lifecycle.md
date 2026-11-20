# Lab 04 - Ciclo de vida de WEB02

## 4.3 Pruebas de rendimiento de WEB02

### Recursos efectivos de la VM

| Parametro | Valor en el .vmx | Valor observado en FreeBSD |
|---|---|---|
| vCPU | `numvcpus = "1"` | `hw.ncpu: 1` |
| RAM | `memsize = "1024"` | `hw.physmem: 1033351168` B = 985,48 MiB |
| Swap | no definido | 1024 MiB, 0 MiB usados |
| MAC | `00:0c:29:9e:c0:72` | unico frente a WEB01 (`00:0c:29:99:01:52`) |

La diferencia entre 1024 MB asignados y 985,48 MiB visibles corresponde a la
memoria reservada por el kernel y las estructuras de arranque; no es un fallo
de configuracion.

### Carga de CPU

Herramienta: `yes > /dev/null &` con `top -d 2` (utilidad de la base, no
`stress-ng`; ver incidencia 4.3.1).

| Metrica | Valor |
|---|---|
| Proceso `yes`, WCPU | 99,67 % |
| CPU instantanea | 23,8 % user, 76,2 % system, 0,0 % idle |
| Load average (1/5/15 min) | 0,26 / 0,31 / 0,32 |
| Procesos en estado RUN | 2 |

El `load average` no alcanza 1,0 porque la media de un minuto todavia arrastra
el periodo inactivo previo; la saturacion real se lee en la linea `CPU`, con
0,0 % idle mientras `yes` consume un nucleo completo. Con 1 vCPU, un solo
proceso en bucle basta para saturar la VM: el rol de WEB02 no debe alojar
cargas de CPU concurrentes.

### Rendimiento criptografico

Herramienta: `openssl speed -evp aes-128-cbc` (OpenSSL 3.5.6, clang).

| Bloque | Operaciones/s | Throughput |
|---|---|---|
| 16 B | 56 813 161 | 908,3 MB/s |
| 64 B | 18 201 394 | 1 164,9 MB/s |
| 256 B | 4 780 263 | 1 223,7 MB/s |
| 1024 B | 1 377 195 | 1 409,2 MB/s |
| 8192 B | 172 709 | 1 414,8 MB/s |
| 16384 B | 87 308 | 1 430,5 MB/s |

El throughput se estabiliza en torno a 1,4 GB/s desde bloques de 1 KiB, lo que
confirma que el cifrado AES-NI del Ryzen 5 5500U se expone correctamente a la
VM y que TLS en WEB02 no sera el cuello de botella.

### Memoria y paginacion

Herramienta: `vmstat 2 5`.

| Metrica | Valor |
|---|---|
| Memoria libre | 839-840 MB |
| Memoria usada (aprox.) | 145,5 MiB (14,8 %) |
| `sr` (paginas examinadas por pageout) | 5, constante |
| `flt` | 119 en la primera muestra, 0 despues |
| Swap usado | 0 MiB de 1024 |
| `us` / `sy` / `id` | 2 / 3 / 93-100 |

Sin actividad de swap y con `sr` plano, 1024 MB son suficientes para el rol
actual. El margen es amplio, pero no debe interpretarse como holgura para
servicios adicionales: la VM no tiene swap configurado mas alla del valor por
defecto y cualquier proceso con fugas de memoria agotaria la RAM antes de
poder paginar.

### 4.3.1 Incidencia abierta: repositorio de paquetes inalcanzable

`pkg install -y sudo` y `pkg install -y stress-ng` no completan. El nombre
`pkgmir.geo.freebsd.org` resuelve a 5.196.63.68 mediante los resolutores
`10.10.20.10` y `10.10.20.2`, pero la conexion HTTPS agota el tiempo
(`Operation timed out`) y `ping` no recibe respuestas. La VM es alcanzable
desde el host en `10.10.20.21:22` (`TcpTestSucceeded: True`), por lo que el
fallo esta en la salida hacia Internet, no en el adaptador ni en el puerto SSH.

Consecuencia: las mediciones se hicieron con utilidades de la base
(`yes`, `top`, `openssl speed`, `vmstat`) en lugar de `stress-ng`. La incidencia
queda abierta y debe resolverse antes de instalar paquetes en WEB02.

### 4.3.2 Endurecimiento de SSH tras habilitar acceso remoto

| Directiva | Valor final | Motivo |
|---|---|---|
| `PermitRootLogin` | `no` | mantiene la linea base del Lab 03 |
| `PasswordAuthentication` | `yes` | permite el acceso de `opsadmin` por PuTTY |
| `KbdInteractiveAuthentication` | `no` | sin cambio |
| `MaxAuthTries` | `3` | sin cambio |
| `AllowGroups` | `wheel` | restringe el acceso al grupo administrativo |

`opsadmin` pertenece a `wheel`, por lo que `AllowGroups wheel` no bloquea su
acceso. `sudo` no esta instalado y no pudo instalarse por la incidencia 4.3.1;
la elevacion se hace con `su -` y contrasena de `root`.
