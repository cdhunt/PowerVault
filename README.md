# PowerVault
PowerShell Client for HashiCorp Vault

This is a PowerShell client for [HashiCorp Vault](https://www.vaultproject.io/). It interfaces with the HTTP API and does not require vault.exe.

The HTTP API is not stable, so this module is not stable.

The module only contains basic CRUD functionality.

## Examples

```powershell
# Create and Read
PS C:\> $vault = Get-Vault -Address 127.0.0.1 -Token 46e231ee-49bb-189d-c58d-f276743ececa

PS C:\> Set-Secret -VaultObject $vault -Path secret/new -Secret @{value="secret"}

PS C:\> Get-Secret $vault secret/new

value 
----- 
secret
```

```powershell
# Retun the Secret as a [PSCredential]
PS C:\> Set-Secret -VaultObject $vault -Path secret/username -Secret @{password="P@55w0rd"}

PS C:\> Get-Secret -VaultObject $vault -Path secret/username -AsCredential 

UserName                       Password
--------                       --------
username   System.Security.SecureString
```

## Testing
The tests depend on Vault.exe to launch a local Dev server. The script will pull down the binaries from HashiCorp to TestDrive:\ and start up a Vault.exe process. All of the files should be cleaned up when the tests complete. 