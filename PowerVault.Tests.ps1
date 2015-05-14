﻿Import-Module .\PowerVault.psd1

Describe "API Compatability" {
    Invoke-WebRequest -Uri https://dl.bintray.com/mitchellh/vault/vault_0.1.2_windows_amd64.zip -OutFile TestDrive:\vault.zip
    New-Item -Path TestDrive:\ -Name Vault -ItemType Directory
    Expand-Archive -Path TestDrive:\Vault.zip -DestinationPath TestDrive:\Vault

    $process = Start-Process -FilePath TestDrive:\Vault\Vault.exe -ArgumentList @('server','-dev') -RedirectStandardOutput TestDrive:\stdout.txt -WindowStyle Hidden -PassThru

    Start-Sleep -Milliseconds 500

    $addr = (Select-String -Path TestDrive:\stdout.txt -SimpleMatch VAULT_ADDR | Select-Object -ExpandProperty Line -First 1).Split('=')[1].Trim("'")
    $token = (Select-String -Path TestDrive:\stdout.txt -SimpleMatch VAULT_TOKEN | Select-Object -ExpandProperty Line -First 1).Split('=')[1].Trim("'")

    $env:VAULT_ADDR = $addr
    $env:VAULT_TOKEN = $token

    # Pre-populate with some known secrets
    TestDrive:\Vault\Vault.exe write secret/hello value=world
    TestDrive:\Vault\Vault.exe write secret/delete value=me
    TestDrive:\Vault\Vault.exe write secret/testwithusername username=usernametest password=p@55w0rd
    TestDrive:\Vault\Vault.exe write secret/testwithoutusername password=p@55w0rd

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

    Context "Create" {

    }

    Context "Read" {     

        $result = Get-Secret $vault secret/hello

        It "Should have a 'value' property" {
            $output = $result | Get-Member -Name value

            $output | Should Not BeNullOrEmpty 
        }

        It "Should return hello world" {

            $result.value | Should BeExactly 'world'            
        }
    }

    Context "Update" {

    }

    Context "Delete" {

    }

   Context "Secret with username property" {

        $result = Get-Secret $vault -Path secret/testwithusername -AsCredential 

        It "Should be a PSCredential" {
            $result.GetType().Name | Should Be 'PSCredential'
        }

        It "Should contain a username property that equals 'usernametest'" {
            $result.UserName | Should BeExactly 'usernametest'
        }
    }

    Context "Secret without username property" {
        
        $result = Get-Secret $vault -Path secret/testwithoutusername -AsCredential 

        It "Should be a PSCredential" {
            $result.GetType().Name | Should Be 'PSCredential'
        }

        It "Should contain a username property that equals 'testwithoutusername'" {
            $result.UserName | Should BeExactly 'testwithoutusername'
        }
    }

    Context "Secret does not exist" {

        It "Should handle an exception" {

            { Get-Secret $vault -Path secret/nohello } | Should Not Throw

        }
    }

    $process.Kill()
}

Remove-Module PowerVault