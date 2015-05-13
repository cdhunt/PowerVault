$prefix = '/v1/'

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-Vault
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([PSCustomObject])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory, Position=0)]
        $Address,

        # client token
        [Parameter(Mandatory, Position=1)]
        $Token,

        # Param2 help description
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
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-Secret
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Object])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory, Position=0)]
        [PSCustomObject]
        $VaultObject,

        # Param1 help description
        [Parameter(Mandatory, Position=1)]
        [String]
        $Path,

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
                }
                else
                {
                    $username = $Path.Split('/')[-1]
                }

                New-Object -TypeName System.Management.Automation.PSCredential `
                -ArgumentList $username, ($data.password | ConvertTo-SecureString -AsPlainText -Force)
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