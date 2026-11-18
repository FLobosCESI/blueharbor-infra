# Lab 02 · AGDLP applied to the Finance share

## Model in place

| Layer | Object | Scope |
|---|---|---|
| A | elaurent, mpetit, lmartin | OU=Finance,OU=Users |
| G | GG_Finance | Global |
| DL | DL_FinanceShare_RW, DL_FinanceShare_R | Domain local |
| P | Share: Change / Read · NTFS: Modify / Read & execute | C:\Shares\Finance |

Verified with `Get-SmbShareAccess -Name Finance` (two DL groups only) and
`icacls C:\Shares\Finance` (RW = M, R = RX, inheritance disabled).

## Case 1 · A fourth accountant joins

Add the account to GG_Finance and nothing else:

    Add-ADGroupMember -Identity GG_Finance -Members (Get-ADUser -Identity <sam>)

No change on the share and no change on NTFS. The new account inherits Change on
the share and Modify on the folder through the existing nesting. That is the point
of AGDLP: permissions are granted to groups, never to accounts, so onboarding is a
single group membership.

## Case 2 · An auditor needs read-only access for one month

Create a temporary global group, nest it in the read domain local group, and give
the membership an end date:

    New-ADGroup -Name GG_Auditors_Q4 -GroupScope Global -GroupCategory Security `
      -Path "OU=Groups,OU=BlueHarbor,DC=blueharbor,DC=internal"
    Add-ADGroupMember -Identity DL_FinanceShare_R -Members GG_Auditors_Q4
    Add-ADGroupMember -Identity GG_Auditors_Q4 -Members <auditor> `
      -MemberTimeToLive (New-TimeSpan -Days 30)

The membership expires by itself after 30 days, so the access disappears without
relying on a reminder. The auditor never enters DL_FinanceShare_RW, so write access
is impossible. At the end of the audit, remove the membership and delete
GG_Auditors_Q4. If the functional level did not support membership TTL, the same
result is obtained with a calendar review and an explicit Remove-ADGroupMember.
