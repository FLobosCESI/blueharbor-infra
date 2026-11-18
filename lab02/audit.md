# Lab 02 · Auditoría del directorio BlueHarbor

## Alcance

Revisión de la delegación de control, la política de contraseñas granular y la aplicación de directivas de grupo sobre el dominio `blueharbor.internal`, con DC01 en `10.10.20.10`. La evidencia se apoya en las consultas ejecutadas en DC01 y en los informes HTML guardados en `lab02/evidence/`.

## Delegación de control (2.5)

`GG_Helpdesk` es un grupo global creado en `OU=Groups,OU=BlueHarbor,DC=blueharbor,DC=internal`. La delegación se aplicó sobre `OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal` mediante una tarea personalizada, porque el asistente en español no resolvía el nombre de la tarea predefinida.

| Elemento | Valor |
|---|---|
| Objeto delegado | OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal |
| Grupo beneficiario | BLUEHARBOR\GG_Helpdesk |
| Derecho extendido | 00299570-246d-11d0-a768-00aa006e0529 (Restablecer contraseña) |
| Herencia | ACE explícita, `IsInherited` = False |
| Verificación | `dsacls` sobre la OU muestra la entrada de restablecimiento para `GG_Helpdesk` |

## Política de contraseñas granular (2.5)

| Parámetro | PSO-Admins | Directiva de dominio |
|---|---|---|
| Precedencia | 10 | — |
| Longitud mínima | 16 | 12 |
| Historial de contraseñas | 24 | — |
| Complejidad | Habilitada | — |
| Cifrado reversible | Deshabilitado | — |
| Caducidad máxima | 90 días | 42 días |
| Umbral de bloqueo | 5 | 5 |
| Duración del bloqueo | 30 minutos | — |
| Ventana de observación | 30 minutos | — |

La PSO está aplicada a `Admins. del dominio`, resuelto por SID terminado en `-512` para evitar el problema de nombres localizados. La verificación con `Get-ADUserResultantPasswordPolicy -Identity Administrador` devuelve `PSO-Admins`, precedencia 10, longitud mínima 16 y caducidad 90 días, lo que confirma que la política granular prevalece sobre la de dominio.

## Aplicación de directivas (2.4)

`BH-Users-Baseline` está enlazada a `OU=Users` con orden 1 y contiene tres valores bajo `HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop`: `ScreenSaveActive` = 1, `ScreenSaverIsSecure` = 1 y `ScreenSaveTimeOut` = 600.

La modelización para `elaurent`, con contenedor de usuario `Users\Finance` y contenedor de equipo `Computers`, muestra `BH-Users-Baseline` en el bloque de configuración de usuario y `Default Domain Policy` en el de equipo. La asimetría es correcta: la GPO solo define valores `HKCU`. El informe completo está en `lab02/evidence/gpo-modeling-elaurent.htm`.

## Hallazgos

| # | Hallazgo | Evidencia | Acción |
|---|---|---|---|
| 1 | La cuenta integrada `Administrador` (RID 500) está exenta del bloqueo de cuenta por diseño de Windows, así que el umbral de 5 intentos de `PSO-Admins` no la protege. | `Get-ADUserResultantPasswordPolicy -Identity Administrador` devuelve `PSO-Admins` con `LockoutThreshold` 5, pero la exención RID 500 se aplica igualmente. | Crear cuentas administrativas nominales, una por persona, dejar la RID 500 deshabilitada o con contraseña custodiada, y añadir MFA y monitorización de inicios de sesión administrativos. |
| 2 | La delegación de `GG_Helpdesk` cubre todo el subárbol de `OU=Users`, incluidos Finance, Operations e IT, no solo el personal de soporte. | ACE con `ExtendedRight` `00299570-246d-11d0-a768-00aa006e0529`, `IsInherited` = False, sobre `OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal`. | Acotar la delegación a una OU de usuarios de soporte o añadir filtrado por objeto, y revisar trimestralmente la pertenencia a `GG_Helpdesk`. |
| 3 | No hay evidencia de auditoría de gestión de cuentas: los reinicios de contraseña delegados no quedan registrados de forma consultable. | El informe de auditoría de directorio no incluye eventos 4723, 4724 ni 4738; no se ha configurado directiva de auditoría avanzada. | Activar «Auditar la gestión de cuentas de usuario» mediante GPO en los controladores de dominio y reenviar los eventos a un colector. |
| 4 | Las contraseñas de los administradores caducan a los 90 días mientras las de los usuarios lo hacen a los 42, de modo que las credenciales con más privilegio viven más tiempo. | `PSO-Admins` con `MaxPasswordAge` 90.00:00:00 frente a `Get-ADDefaultDomainPasswordPolicy` con `MaxPasswordAge` 42.00:00:00. | Alinear la PSO a 42 días o justificar la excepción por escrito, y compensar con MFA para las cuentas administrativas. |
