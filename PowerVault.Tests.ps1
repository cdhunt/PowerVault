Import-Module "$PSScriptRoot\PowerVault.psd1"

Describe "PowerVault" {
     Context "Basic Secret" {
        Mock -ModuleName PowerVault Invoke-RestMethod { return [PSCustomObject]@{data=[PSCustomObject]@{value="world"}} }

        $result = Get-Secret -VaultObject $vault -Path secret/hello 

        It "Should contain a username property that equals 'test'" {
            $result.value | Should BeExactly 'world'
        }
    }
 
    Context "Secret with username property" {
        Mock -ModuleName PowerVault Invoke-RestMethod { return [PSCustomObject]@{data=[PSCustomObject]@{UserName="test"; Password="P@ssw0rd"}} }

        $result = Get-Secret -VaultObject $vault -Path secret/test -AsCredential 

        It "Should be a PSCredential" {
            $result.GetType().Name | Should Be 'PSCredential'
        }

        It "Should contain a username property that equals 'test'" {
            $result.UserName | Should BeExactly 'test'
        }
    }

    Context "Secret without username property" {
        Mock -ModuleName PowerVault Invoke-RestMethod { return [PSCustomObject]@{data=[PSCustomObject]@{password="P@ssw0rd"}} }

        $result = Get-Secret -VaultObject $vault -Path secret/test -AsCredential 

        It "Should contain a username property that equals 'test'" {
            $result.UserName | Should BeExactly 'test'
        }
    }

    Context "Secret does not exist" {
        Mock -ModuleName PowerVault Invoke-RestMethod { throw 'The remote server returned an error: (404) Not Found.' }

        It "Should handle an exception" {

            { Get-Secret -VaultObject $vault -Path secret/nohello } | Should Not Throw

        }
    }
}

Remove-Module PowerVault