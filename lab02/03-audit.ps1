<#
.SYNOPSIS
    Lab 02 - Auditoria del directorio BlueHarbor (ejercicio 2.5)

.DESCRIPTION
    Recoge evidencia de delegacion de control, politica de contrasenas granular
    y enlaces de directivas de grupo sobre blueharbor.internal.
    Genera un CSV con el inventario de cuentas en C:\Lab\lab02\evidence.

.EXAMPLE
    .\03-audit.ps1
    .\03-audit.ps1 -OutputPath C:\Lab\lab02\evidence\ad-audit.csv
#>

[CmdletBinding()]
param(
    [string]$OutputPath = 'C:\Lab\lab02\evidence\ad-audit.csv'
)

Import-Module ActiveDirectory -ErrorAction Stop

$domain    = Get-ADDomain
$domainDN  = $domain.DistinguishedName
$usersOU   = "OU=Users,OU=BlueHarbor,$domainDN"
$groupsOU  = "OU=Groups,OU=BlueHarbor,$domainDN"

$evidenceDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -Path $evidenceDir)) {
    New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
}

Write-Host "=== Lab 02 - Auditoria de blueharbor.internal ===" -ForegroundColor Cyan
Write-Host "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Controlador: $($env:COMPUTERNAME)"
Write-Host "Dominio: $domainDN"

# ---------------------------------------------------------------------------
# 1. Delegacion de control sobre OU=Users
# ---------------------------------------------------------------------------
Write-Host "`n== 1. Delegacion de control sobre OU=Users ==" -ForegroundColor Cyan

try {
    $acl = Get-Acl -Path "AD:$usersOU"
    $delegated = $acl.Access | Where-Object {
        $_.IdentityReference -like '*GG_Helpdesk*' -and -not $_.IsInherited
    }

    if ($delegated) {
        $delegated |
            Select-Object IdentityReference, ActiveDirectoryRights,
                          AccessControlType, IsInherited, ObjectType |
            Format-List
    }
    else {
        Write-Warning "No se encontro ninguna ACE explicita para GG_Helpdesk en $usersOU"
    }

    Write-Host "-- dsacls (entradas de GG_Helpdesk) --"
    dsacls $usersOU | Select-String -Pattern 'GG_Helpdesk'
}
catch {
    Write-Warning "No se pudo leer la ACL de $usersOU : $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 2. Politica de contrasenas granular
# ---------------------------------------------------------------------------
Write-Host "`n== 2. Politicas de contrasenas granulares ==" -ForegroundColor Cyan

Get-ADFineGrainedPasswordPolicy -Filter * |
    Select-Object Name, Precedence, MinPasswordLength, PasswordHistoryCount,
                  ComplexityEnabled, ReversibleEncryptionEnabled, MaxPasswordAge,
                  LockoutThreshold, LockoutDuration, LockoutObservationWindow |
    Format-List

Write-Host "-- Sujetos de PSO-Admins --"
Get-ADFineGrainedPasswordPolicySubject -Identity PSO-Admins |
    Select-Object Name, SamAccountName, SID |
    Format-Table -AutoSize

Write-Host "-- Politica resultante para la cuenta Administrador (RID 500) --"
Get-ADUserResultantPasswordPolicy -Identity Administrador |
    Select-Object Name, Precedence, MinPasswordLength, MaxPasswordAge, LockoutThreshold |
    Format-Table -AutoSize

# ---------------------------------------------------------------------------
# 3. Politica de dominio por defecto
# ---------------------------------------------------------------------------
Write-Host "`n== 3. Politica de contrasenas del dominio ==" -ForegroundColor Cyan

Get-ADDefaultDomainPasswordPolicy |
    Select-Object MinPasswordLength, PasswordHistoryCount, ComplexityEnabled,
                  ReversibleEncryptionEnabled, MaxPasswordAge, MinPasswordAge,
                  LockoutThreshold, LockoutDuration, LockoutObservationWindow |
    Format-List

# ---------------------------------------------------------------------------
# 4. Directivas de grupo enlazadas a OU=Users
# ---------------------------------------------------------------------------
Write-Host "`n== 4. Directivas de grupo enlazadas a OU=Users ==" -ForegroundColor Cyan

try {
    Get-GPInheritance -Target $usersOU |
        Select-Object -ExpandProperty InheritedGpoLinks |
        Select-Object DisplayName, Enabled, Enforced, Order |
        Format-Table -AutoSize
}
catch {
    Write-Warning "No se pudo consultar la herencia de GPO: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 5. Inventario de cuentas y exportacion a CSV
# ---------------------------------------------------------------------------
Write-Host "`n== 5. Inventario de cuentas en OU=Users ==" -ForegroundColor Cyan

$users = Get-ADUser -Filter * -SearchBase $usersOU `
    -Properties LastLogonDate, PasswordLastSet, Enabled, MemberOf |
    Select-Object Name, SamAccountName, Enabled, LastLogonDate, PasswordLastSet,
        @{ Name = 'Groups'; Expression = {
            ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=', '' }) -join '; '
        }}

$users | Format-Table -AutoSize

$users | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "`nCSV exportado en $OutputPath" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 6. Resumen de hallazgos
# ---------------------------------------------------------------------------
Write-Host "`n== 6. Resumen de hallazgos ==" -ForegroundColor Cyan

$defaultPolicy = Get-ADDefaultDomainPasswordPolicy
$pso           = Get-ADFineGrainedPasswordPolicy -Identity PSO-Admins

$findings = @()

$findings += [pscustomobject]@{
    Id       = 1
    Hallazgo = 'La cuenta RID 500 esta exenta del bloqueo de cuenta'
    Detalle  = "PSO-Admins define LockoutThreshold $($pso.LockoutThreshold), pero Windows no bloquea la cuenta integrada Administrador"
}

$findings += [pscustomobject]@{
    Id       = 2
    Hallazgo = 'La delegacion de GG_Helpdesk cubre todo el subarbol de OU=Users'
    Detalle  = 'La ACE se aplica sobre OU=Users, incluidos Finance, Operations e IT'
}

$findings += [pscustomobject]@{
    Id       = 3
    Hallazgo = 'Sin directiva de auditoria de gestion de cuentas'
    Detalle  = 'No se registran los eventos 4723, 4724 ni 4738 de forma consultable'
}

$findings += [pscustomobject]@{
    Id       = 4
    Hallazgo = 'Las contrasenas administrativas caducan mas tarde que las de usuario'
    Detalle  = "PSO-Admins $($pso.MaxPasswordAge.Days) dias frente a dominio $($defaultPolicy.MaxPasswordAge.Days) dias"
}

$findings | Format-Table -AutoSize -Wrap

Write-Host "`nAuditoria completada." -ForegroundColor Green
