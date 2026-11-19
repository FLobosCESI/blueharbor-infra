# Lab 03 - Informe USE de WEB01

## 1. Contexto y alcance

Host WEB01 con FreeBSD 15.1-RELEASE (GENERIC) releng/15.1-n283562-96841ea08dcf,
IP 10.10.20.20/24, gateway 10.10.20.2, DNS 10.10.20.10, particionado Auto (UFS)
sobre ada0 GPT, interfaz em0. Acceso por PuTTY como opsadmin (UID 1001, wheel,
tcsh) con clave opsadmin_WEB01.ppk.

Este informe cubre el metodo USE (Utilization, Saturation, Errors) aplicado con
vmstat, mpstat, iostat -xz, top y stress-ng, segun el apartado 3.3 del workbook.

## 2. Metodo

Cada recurso se mide en tres ejes: utilizacion, saturacion y errores. La carga se
genera con stress-ng acotado en tamano y en tiempo, y se vigila el consumo de
disco en paralelo con un bucle de df -h / cada 5 segundos.

## 3. Disco (hdd)

### 3.1 Incidencia previa

La primera ejecucion se lanzo como `stress-ng --hdd 1` sin limite de tamano. El
stressor crecio hasta llenar el disco del portatil anfitrion: C: quedo con
223622967296 bytes usados y 14657085440 libres (unos 208 GB ocupados y 13,6 GB
disponibles). Las dos maquinas virtuales, WEB01 y DC01, se cayeron.

No se trataba de un fallo de WEB01: `du -xhd 1 /` sobre la raiz suma 2,2 GB, con
/usr en 1,5 GB, /var en 240 MB y /boot en 180 MB, y `df -h /` reporta 18 GB
totales, 2,2 GB usados y 15 GB disponibles al 13 %. El sistema de archivos del
invitado nunca estuvo lleno.

### 3.2 Repeticion acotada

Comando ejecutado como opsadmin, con nohup para sobrevivir al cierre de PuTTY:

    nohup stress-ng --hdd 1 --hdd-bytes 512M --temp-path /tmp --timeout 60s \
      --metrics-brief >& /tmp/stress-hdd.log &

Salida registrada en lab03/evidence/stress-hdd.log (799 bytes):

    stress-ng: info:  [79290] setting to a 1 min run per stressor
    stress-ng: info:  [79290] dispatching hogs: 1 hdd
    stress-ng: info:  [79548] hdd: using 512M file system space per stressor
      instance (total 512M of 118.09G available file system space)
    stress-ng: metrc: [79290] hdd  659318  60.03  8.30  50.60  10983.57  11194.34
    stress-ng: info:  [79290] passed: 1 hdd (1)
    stress-ng: info:  [79290] failed: 0
    stress-ng: info:  [79290] successful run completed in 1 min

Lectura: 659318 bogo ops en 60,03 s de tiempo real, con 8,30 s de CPU de usuario
y 50,60 s de CPU de sistema. El dominio del tiempo de sistema sobre el de usuario
es el comportamiento esperado en un stressor de disco, porque el trabajo se
resuelve en el kernel y en la capa de E/S. `passed: 1 hdd (1)` y `failed: 0`
indican que el stressor completo su ciclo sin errores.

### 3.3 Serie del vigilante

Bucle lanzado en paralelo, con 24 muestras y parada automatica:

    nohup sh -c 'i=0; while [ $i -lt 24 ]; do date "+%H:%M:%S" >> /tmp/df-watch.log;
      df -h / >> /tmp/df-watch.log; i=$((i+1)); sleep 5; done' >& /tmp/df-watch.err &

Serie conservada en lab03/evidence/df-watch.log (72 lineas, 2688 bytes):

| Muestra | Hora     | Usado | Disponible | Uso |
|----|----|----|----|----|
| Primera | 22:25:01 | 2,2G  | 15G        | 13% |
| Pico    | 22:25:41 | 2,6G  | 14G        | 16% |
| Pico    | 22:26:57 | 2,6G  | 14G        | 16% |

El incremento maximo es de unos 400 MB sobre la linea base, coherente con el
archivo de 512 MB que crea `--hdd-bytes 512M`. La serie cierra en el pico; la
vuelta a la linea base la confirma el `df -h /` posterior a la prueba, con 2,2G
usados, 15G disponibles y 13 %.

### 3.4 Sintesis USE del disco

Utilizacion: maxima del 16 % del sistema de archivos raiz durante la carga.
Saturacion: sin saturacion, el stressor se limita a 512 MB y termina por tiempo.
Errores: ninguno, `failed: 0` y sin residuos `stress-ng-*` en /tmp tras la
prueba; `pgrep -laf stress-ng` no devuelve procesos al finalizar.

## 4. CPU (top y vmstat)

### 4.1 Condicion de captura

Las capturas de los apartados 4 a 7 se tomaron a las 23:26:35, con el sistema en
reposo: `top` no muestra ningun proceso `stress-ng` y la CPU esta al 99,2 % en
idle. Documentan por tanto la linea base sin carga; las cifras del stressor en
ejecucion son las del apartado 3.2.

### 4.2 mpstat no disponible

`mpstat 1 5` devuelve `timeout: exec(mpstat): No such file or directory`. La
herramienta pertenece al paquete `sysutils/sysstat` y no forma parte del sistema
base de FreeBSD 15.1. El eje de CPU se cubre con `top` y `vmstat`, ambos en el
sistema base.

### 4.3 top

    last pid: 62611;  load averages:  0.16,  0.25,  0.25   up 0+04:03:18  23:26:35
    4 processes:  1 running, 3 sleeping
    CPU: 0.1% user,  0.0% nice,  0.7% system,  0.0% interrupt, 99.2% idle

### 4.4 vmstat -w 1 5

Tres muestras validas; el conteo no se respeto y el resto del archivo son
muestras adicionales hasta la interrupcion.

| Muestra | r | b | w | in | sy (llamadas) | cs | us | sy (CPU) | id |
|----|----|----|----|----|----|----|----|----|----|
| 1 | 0 | 0 | 0 | 11 | 439 | 207 | 0 | 0 | 99 |
| 2 | 0 | 0 | 0 | 2  | 141 | 133 | 0 | 0 | 99 |
| 3 | 0 | 0 | 0 | 2  | 148 | 134 | 0 | 0 | 99 |

### 4.5 Sintesis USE de CPU

Utilizacion: 0,8 % (0,1 % usuario y 0,7 % sistema) segun top; vmstat redondea a
0 % de usuario y 0 % de sistema con 99 % en idle en las tres muestras.
Saturacion: load averages de 0,16, 0,25 y 0,25 con 4 procesos, y cola de
ejecucion `r` a 0 en las tres muestras; no hay procesos esperando CPU.
Errores: ninguno.

## 5. Memoria (vmstat)

### 5.1 top

    Mem: 5320K Active, 53M Inact, 85M Wired, 1980K Buf, 1819M Free
    Swap: 1024M Total, 1024M Free

### 5.2 vmstat -w 1 5

| Muestra | fre (bytes) | flt | re | pi | po | fr | sr |
|----|----|----|----|----|----|----|----|
| 1 | 1907322880 | 47 | 0 | 0 | 0 | 1126 | 4 |
| 2 | 1907314688 | 1  | 0 | 0 | 0 | 2    | 2 |
| 3 | 1907314688 | 1  | 0 | 0 | 0 | 2    | 2 |

La columna `fre` viene en bytes: 1907322880 bytes son 1818,96 MB, es decir los
1819 MB libres que reporta top. Ambas herramientas coinciden.

### 5.3 Sintesis USE de memoria

Utilizacion: unos 1964 MB comprometidos de los 2048 MB asignados a la VM, con
1819 MB libres, 85 MB wired y 53 MB inactivos.
Saturacion: `pi` y `po` a 0 en las tres muestras, sin paginacion hacia swap, y
swap con 1024M libres de 1024M, es decir 0 % usado. `sr`, paginas exploradas por
el pageout daemon, se queda en 4, 2 y 2, sin presion de reclamacion.
Errores: ninguno.

La columna `avm` devuelve 4398427201536 en las tres muestras, valor incoherente
con 2 GB de RAM; se descarta y no se usa en el analisis.

## 6. E/S por dispositivo (iostat -xz)

### 6.1 da0

| Muestra | r/s | w/s | kr/s | kw/s  | ms/r | ms/w | ms/t | qlen | %b |
|----|----|----|----|----|----|----|----|----|----|
| 1 | 0 | 5 | 13,6 | 4256,6 | 1 | 3 | 3 | 0 | 1 |
| 2 | 0 | 1 | 0,0  | 0,5    | 0 | 0 | 0 | 0 | 0 |
| 3 | 0 | 2 | 0,0  | 7,7    | 0 | 0 | 0 | 0 | 0 |

### 6.2 cd0

Las tres muestras dan 0 en todas las columnas: la unidad optica no registra
actividad.

### 6.3 Sintesis USE de E/S

Utilizacion: `%b` con maximo del 1 % en da0, en la primera muestra, y 0 % en las
dos siguientes.
Saturacion: `qlen` a 0 en todas las muestras, sin peticiones en cola, y `ms/t`
con maximo de 3 ms.
Errores: ninguno.

El pico de 4256,6 kw/s de la primera muestra corresponde a la escritura inicial
del archivo del stressor y no se sostiene: las muestras siguientes bajan a 0,5 y
7,7 kw/s.

## 7. Vision de procesos (top)

    PID USERNAME  THR PRI NICE   SIZE    RES STATE    C   TIME    WCPU COMMAND
    85639 opsadmin    1   0    0    17M  4900K sigsus   1   0:01   0.00% tcsh
    84859 opsadmin    1   0    0    28M    11M select   0   0:00   0.00% sshd-session

La cabecera contabiliza 4 procesos, 1 en ejecucion y 3 dormidos, y la tabla lista
dos: la sesion `tcsh` de opsadmin y su `sshd-session`. Ambos estan al 0,00 % de
CPU y en estado de espera, `sigsus` y `select`. No aparece ningun proceso
`stress-ng`, lo que confirma la condicion de captura del apartado 4.1.

## 8. Evidencias

- lab03/evidence/stress-hdd.log - salida completa de stress-ng, 799 bytes.
- lab03/evidence/df-watch.log - serie de df -h /, 72 lineas, 2688 bytes.
- lab03/evidence/use-idle.log - captura inicial, 30175 bytes.
- lab03/evidence/use-vmstat.log - vmstat -w 1 5, 440 bytes, 5 lineas.
- lab03/evidence/use-mpstat.log - mpstat 1 5, 528 bytes, 1 linea (error).
- lab03/evidence/use-iostat.log - iostat -xz 1 5, 963 bytes, 14 lineas.
- lab03/evidence/use-top.log - top -b -d 1 -n 2, 49 bytes, 10 lineas.

## 9. Desviaciones registradas

- DNS y reenviador en 10.10.20.2 porque 1.1.1.1 no responde en esta red.
- Variable $initPwd en lugar de $pwd.
- open-vm-tools instalado con dependencias X11 en vez del flavor nox11.
- opsadmin en UID 1001, a alinear con UID 1000 en el Lab 08.
- stress-ng reproducido con limite explicito de 512 MB y 60 s tras la incidencia.
- mpstat no forma parte del sistema base de FreeBSD 15.1, viene en
  sysutils/sysstat; la captura devuelve "No such file or directory" y el eje de
  CPU se cubre con top y vmstat.
- La columna avm de vmstat -w devuelve 4398427201536, incoherente con 2 GB de
  RAM; se descarta y se usa fre, que si coincide con top.
- use-idle.log contiene lineas "Command not found" por el pegado multilinea en
  tcsh; las muestras de vmstat que contiene son validas.
- El conteo de muestras de vmstat no se respeto; se acoto con timeout 12 y se
  conservaron las muestras completas.
