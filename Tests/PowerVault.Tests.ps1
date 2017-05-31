Import-Module $PSScriptRoot\..\PowerVault\PowerVault.psd1 -Force

Describe 'API Compatability' {
    <#
    Invoke-WebRequest -Uri "http://releases.hashicorp.com/vault/0.7.2/vault_0.7.2_windows_amd64.zip?_ga=2.92103002.1726850924.1496071924-932259573.1496071923" -OutFile $PSScriptRoot\vault.zip -UseBasicParsing
    New-Item -Path TestDrive:\ -Name Vault -ItemType Directory

    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        Expand-Archive -Path $PSScriptRoot\Vault.zip -DestinationPath $PSScriptRoot
    }
    else
    {
        $shell = new-object -com shell.application
        $zip = $shell.NameSpace("$PSScriptRoot\vault.zip")
        foreach($item in $zip.items())
        {
            $shell.Namespace(“$PSScriptRoot\vault.zip”).copyhere($item)
        }

        Copy-Item -Path & "$PSScriptRoot\Vault.exe" -Destination $PSScriptRoot\
    }

    Remove-Item -Path $PSScriptRoot\vault.zip
    #>
    $process = Start-Process -FilePath "$PSScriptRoot\Vault.exe" -ArgumentList @('server','-dev') -RedirectStandardOutput TestDrive:\stdout.txt -WindowStyle Hidden -PassThru

    Start-Sleep -Milliseconds 500

    try
        {

        $addr = (Get-Content -Path TestDrive:\stdout.txt | Select-String -SimpleMatch VAULT_ADDR | Select-Object -ExpandProperty Line -First 1).Split('=')[1].Trim("'")
        $token = (Get-Content -Path TestDrive:\stdout.txt | Select-String -SimpleMatch "Root Token:" | Select-Object -ExpandProperty Line -First 1).Split(':')[1].Trim()

        $env:VAULT_ADDR = $addr
        $env:VAULT_TOKEN = $token

        # Pre-populate with some known secrets
        & "$PSScriptRoot\Vault.exe" write secret/hello value=world
        & "$PSScriptRoot\Vault.exe" write secret/delete value=me
        & "$PSScriptRoot\Vault.exe" write secret/update value=was
        & "$PSScriptRoot\Vault.exe" write secret/testwithusername username=usernametest password=p@55w0rd
        & "$PSScriptRoot\Vault.exe" write secret/testwithoutusername password=p@55w0rd

        $vault = Get-Vault

        Context 'Test Get-Vault Parameters' {

            It 'Should work with $env' {
                $result = Get-Vault

                $result.uri | Should BeExactly "$addr/v1/"
                $result.auth_header.'X-Vault-Token' | Should BeExactly $token
            }

            It 'Should work with parametres' {
                $result = Get-Vault -Address http://127.0.0.1:8300 -Token abc-123

                $result.uri | Should BeExactly 'http://127.0.0.1:8300/v1/'
                $result.auth_header.'X-Vault-Token' | Should BeExactly 'abc-123'
            }
        }


        Context 'Verify Server Started' {
            $result = Test-Vault $vault

            It 'Should be Initialized' {
                $result.initialized | Should Be $true
            }
            It "Should not be Sealed" {
                $result.sealed | Should Be $false
            }
        }

        Context 'Create' {
            Set-Secret $vault secret/new @{value='secret'}

            $json = & "$PSScriptRoot\Vault.exe" --% read -format=json secret/new
            $result = $json | ConvertFrom-Json

            It 'Should contain a new secret' {
                $result | Should Not BeNullOrEmpty
                $result.data.value | Should BeExactly 'secret'
            }
        }

        Context "Read" {

            $result = Get-Secret $vault secret/hello

            It "Should have a 'value' property" {
                $output = $result | Get-Member -Name value

                $output | Should Not BeNullOrEmpty
            }

            It 'Should return hello world' {

                $result.value | Should BeExactly 'world'
            }
        }

        Context 'Update' {
            Set-Secret $vault secret/update @{value='now'}

            $json = & "$PSScriptRoot\Vault.exe" --% read -format=json secret/update
            $result = $json | ConvertFrom-Json

            It "Should contain a new secret" {
                $result | Should Not BeNullOrEmpty
                $result.data.value | Should BeExactly 'now'
            }

        }

        Context 'Delete' {
            Remove-Secret $vault secret/delete

            $json = & "$PSScriptRoot\Vault.exe" 'read', '-format=json', 'secret/delete' 2> TestDrive:\stderr.txt

            It 'Should be not contain the secret' {
                $json | Should BeNullOrEmpty
            }

        }

    Context 'Secret with username property' {

            $result = Get-Secret $vault -Path secret/testwithusername -AsCredential

            It 'Should be a PSCredential' {
                $result.GetType().Name | Should Be 'PSCredential'
            }

            It "Should contain a username property that equals 'usernametest'" {
                $result.UserName | Should BeExactly 'usernametest'
            }
        }

        Context 'Secret without username property' {

            $result = Get-Secret $vault -Path secret/testwithoutusername -AsCredential

            It 'Should be a PSCredential' {
                $result.GetType().Name | Should Be 'PSCredential'
            }

            It "Should contain a username property that equals 'testwithoutusername'" {
                $result.UserName | Should BeExactly 'testwithoutusername'
            }
        }

        Context 'Secret does not exist' {

            It 'Should handle an exception' {

                { Get-Secret $vault -Path secret/nohello } | Should Not Throw

            }
        }
    }
    catch {

        $process.Kill()
    }

}

Remove-Module PowerVault