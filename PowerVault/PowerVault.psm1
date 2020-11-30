$prefix = '/v1/'

<#
.Synopsis
   Return an Object containing Vault connection details.
.DESCRIPTION
   This is session variable required by all other Cmdlets.
.EXAMPLE
   PS C:\> $vault = Get-Vault -Address 127.0.0.1 -Token 46e231ee-49bb-189d-c58d-f276743ececa
#>
function Get-Vault
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([PSCustomObject])]
    Param
    (
        # Server Address
        [Parameter(Position=0)]
        [String]
        $Address = $env:VAULT_ADDR,

        # Client token
        [Parameter(Position=1)]
        [String]
        $Token = $env:VAULT_TOKEN
    )


    [PSCustomObject]@{'uri'= $Address + $prefix
                      'auth_header' = @{'X-Vault-Token'=$Token}
                      } |
    Write-Output

}

<#
.Synopsis
   Test connectivity to the Vault server.
.DESCRIPTION
   This method returns the health of the server if it can connect.
.EXAMPLE
   PS C:\> Test-Vault $vault

   initialized sealed standby
   ----------- ------ -------
          True  False   False
#>
function Test-Vault
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Object])]
    Param
    (
        # The Object containing Vault access details.
        [Parameter(Mandatory, Position=0)]
        [PSCustomObject]
        $VaultObject

    )

    $uri = $VaultObject.uri + 'sys/health'

    Write-Debug $uri

    Invoke-RestMethod -Uri $uri -Headers $VaultObject.auth_header | Write-Output
}

<#
.Synopsis
   Access a Secret in the Vault
.DESCRIPTION
   This can return a [PSCustomObject] base don the raw Secret or attempt to return a [PSCredential] object.
.EXAMPLE
   PS C:\> Get-Secret -VaultObject $vault -Path secret/hello

   value
   -----
   world
.EXAMPLE
   PS C:\> Get-Secret -VaultObject $vault -Path secret/username -AsCredential

   UserName                       Password
   --------                       --------
   username   System.Security.SecureString
.LINK
   https://www.vaultproject.io/docs/http/index.html
   Get-Vault
.NOTES
   At the current version, Vault does not yet promise backwards compatibility even with the v1 prefix. We'll remove this warning when this policy changes. We expect we'll reach API stability by Vault 0.3.
#>
function Get-Secret
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
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

    $uri = $VaultObject.uri + $Path + '/?list=true'

    $result = [string]::Empty

    Write-Debug $uri

    try
    {
        $result = Invoke-RestMethod -Uri $uri -Headers $VaultObject.auth_header
    }
    catch
    {
        Throw ("Failed to get secret from " + $uri)
    }

    if ($result)
    {
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
                        Write-Verbose "Found a username property in the results. [$username]"
                    }
                    else
                    {
                        $username = $Path.Split('/')[-1]
                        Write-Verbose "Did not find a username property, parsing path. [$username]"
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
    else
    {
        Write-Debug $result
        Write-Verbose "No Secret found. [$Path]"
    }

}

<#
.Synopsis
   Create or update a Secret
.DESCRIPTION
   This will set the contents of a Secret.
.EXAMPLE
   PS C:\> Set-Secret -VaultObject $vault -Path secret/new -Secret @{value="secret"}

   PS C:\> Get-Secret $vault secret/new

   value
   -----
   secret
#>
function Set-Secret
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # The Object containing Vault access details.
        [Parameter(Mandatory, Position=0)]
        [PSCustomObject]
        $VaultObject,

        # The Path to the Secret as you would pass to Vault Read.
        [Parameter(Mandatory, Position=1)]
        [String]
        $Path,

        # The Secret. This will be converted to JSON. A simple Hash works best.
        [Parameter(Mandatory, Position=2)]
        [Object]
        $Secret
    )

    $uri = $VaultObject.uri + $Path

    Write-Debug $uri

    try
    {
        $data = $Secret | ConvertTo-Json

        Write-Debug $data
    }
    catch
    {
        throw "Cannot convert Secret to JSON"
    }

    Invoke-RestMethod -Uri $uri -Method Post -Headers $VaultObject.auth_header -Body $data | Write-Output

}


<#
.Synopsis
   Delete a Secret
.DESCRIPTION
   This will set the delete of a Secret.
.EXAMPLE
   PS C:\> Remove-Secret $vault secret/new

   PS C:\> Get-Secret $vault secret/new -Verbose

   VERBOSE: No Secret found. [secret/new]
#>
function Remove-Secret
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # The Object containing Vault access details.
        [Parameter(Mandatory, Position=0)]
        [PSCustomObject]
        $VaultObject,

        # The Path to the Secret as you would pass to Vault Read.
        [Parameter(Mandatory, Position=1)]
        [String]
        $Path
    )

    $uri = $VaultObject.uri + $Path

    Write-Debug $uri


    Invoke-RestMethod -Uri $uri -Method Delete -Headers $VaultObject.auth_header| Write-Output

}
