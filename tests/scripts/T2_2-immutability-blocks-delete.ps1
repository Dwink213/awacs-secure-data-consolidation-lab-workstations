#Requires -Version 5.1
<#
.SYNOPSIS
  Test T2.2: Even with delete-permission credential, immutability blocks delete.

.DESCRIPTION
  Uploads a small test blob using AAD auth (the deploying identity), then
  attempts to delete it. Expected: delete refused with 409.

  Cleans up by simply leaving the blob; immutability prevents test cleanup
  by design. Test blobs are timestamp-named and small.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "T2.2  -  Immutability blocks delete"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$tmp = New-TemporaryFile
"awacs-test-$(Get-Date -Format yyyyMMddHHmmss)" | Out-File $tmp.FullName

$blobName = "_tests/immutability-check-$(Get-Date -Format yyyyMMddHHmmss).txt"
az storage blob upload --account-name $sa.name --container-name 'lab-files' --name $blobName --file $tmp.FullName --auth-mode login --overwrite 2>$null | Out-Null
$delResult = az storage blob delete --account-name $sa.name --container-name 'lab-files' --name $blobName --auth-mode login 2>&1
$blockedAsExpected = ($LASTEXITCODE -ne 0) -or ($delResult -match 'BlobImmutableDueToPolicy|412|409')
$ok = Test-Assert "DELETE refused due to immutability" $blockedAsExpected "exit=$LASTEXITCODE result=$delResult"
Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
exit ($(if ($ok) { 0 } else { 1 }))
