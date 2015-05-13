$prefix = '/v1/'

<#
.Synopsis
   Return an Object containing Vault connection details.
.DESCRIPTION
   This is session variable required by all other Cmdlets.
.EXAMPLE
   $vault = Get-Vault -Address 127.0.0.1 -Token 46e231ee-49bb-189d-c58d-f276743ececa
#>
function Get-Vault
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([PSCustomObject])]
    Param
    (
        # Server Address
        [Parameter(Mandatory, Position=0)]
        $Address,

        # Client token
        [Parameter(Mandatory, Position=1)]
        $Token,

        # Server Port
        [Parameter(Position=2)]
        [int]
        $Port = 8200
    )

 
    [PSCustomObject]@{'uri'= $env:VAULT_ADDR + $prefix
                      'auth_header' = @{'X-Vault-Token'=$env:VAULT_TOKEN}
                      } |
    Write-Output

}

<#
.Synopsis
   Access a Secret in the Vault
.DESCRIPTION
   This can return a [PSCustomObject] base don the raw Secret or attempt to return a [PSCredential] object.
.EXAMPLE
   Get-Secret -VaultObject $vault -Path secret/hello

   value
   -----
   world
.EXAMPLE
   Get-Secret -VaultObject $vault -Path secret/username -AsCredential 

   UserName                       Password
   --------                       --------
   username   System.Security.SecureString
.LINK
   Get-Vault
   https://www.vaultproject.io/docs/http/index.html
.NOTES
   At the current version, Vault does not yet promise backwards compatibility even with the v1 prefix. We'll remove this warning when this policy changes. We expect we'll reach API stability by Vault 0.3.
#>
function Get-Secret
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Object])]
    Param
    (
        # The Object containing Vault access details.
        [Parameter(Mandatory, Position=0)]
        [PSCustomObject]
        $VaultObject,

        # The Path to the secret as you would pass to Vault Read.
        [Parameter(Mandatory, Position=1)]
        [String]
        $Path,

        # Attempt to convert the Secret to a [PSCredential]. If the Secret contains a username property that will be used else the function will fall back to using the Secret name.
        [Parameter()]
        [switch]
        $AsCredential
    )

    $uri = $VaultObject.uri + $Path

    Write-Debug $uri

    $result = Invoke-RestMethod -Uri $uri -Headers $VaultObject.auth_header

    if ($result.GetType().Name -eq 'PSCustomObject')
    {        
        if ($result | Get-Member -Name data)
        {
            $data = $result | Select-Object -ExpandProperty data

            if ($AsCredential)
            {
                $username = [string]::Empty

                if ($data | Get-Member -Name username)
                {                    
                    $username = $data.username
                    Write-Debug "Found a username property in the results. [$username]"
                }
                else
                {
                    $username = $Path.Split('/')[-1]
                    Write-Debug "Did not find a username property, parsing path. [$username]"
                }

                if ($data | Get-Member -Name password)
                {
                    New-Object -TypeName System.Management.Automation.PSCredential `
                    -ArgumentList $username, ($data.password | ConvertTo-SecureString -AsPlainText -Force)
                }
                else
                {
                    Write-Debug $result
                    throw "The data did not contain a password property."
                }
            }
            else
            {
                Write-Output -InputObject $data
            }
        }
    }
    else
    {
        throw $result
    }

}

Export-ModuleMember -Function Get-Vault, Get-Secret