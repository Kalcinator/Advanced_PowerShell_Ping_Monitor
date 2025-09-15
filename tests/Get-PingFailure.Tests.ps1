$ErrorActionPreference = 'Stop'

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..' 'advanced-ping-monitor.ps1'

    $null = [System.IO.File]::Exists($scriptPath) -or throw "Unable to locate script at $scriptPath."

    $tokens = $null
    $errors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)

    function Import-AstDefinition {
        param(
            [Parameter(Mandatory = $true)]
            [System.Management.Automation.Language.Ast]$Ast,

            [Parameter(Mandatory = $true)]
            [type]$AstType,

            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        $definition = $Ast.Find({ param($node) ($node -is $AstType) -and $node.Name -eq $Name }, $true)
        if (-not $definition) {
            throw "Unable to locate definition for '$Name'."
        }

        Invoke-Expression $definition.Extent.Text
    }

    Import-AstDefinition -Ast $scriptAst -AstType ([System.Management.Automation.Language.TypeDefinitionAst]) -Name 'PingFailureType'
    Import-AstDefinition -Ast $scriptAst -AstType ([System.Management.Automation.Language.TypeDefinitionAst]) -Name 'PingFailure'
    Import-AstDefinition -Ast $scriptAst -AstType ([System.Management.Automation.Language.FunctionDefinitionAst]) -Name 'Get-PingFailure'

    Remove-Item Function:Import-AstDefinition -ErrorAction SilentlyContinue
}

Describe 'Get-PingFailure' {
    It 'maps timed out status to the TimedOut failure type' {
        $failure = Get-PingFailure -Status ([System.Net.NetworkInformation.IPStatus]::TimedOut)

        $failure.Type | Should -Be ([PingFailureType]::TimedOut)
        $failure.OriginalStatus | Should -Be 'TimedOut'
        $failure.DisplayMessage | Should -Be 'Request timed out'
    }

    It 'classifies host unreachable statuses correctly' {
        $failure = Get-PingFailure -Status ([System.Net.NetworkInformation.IPStatus]::DestinationHostUnreachable)

        $failure.Type | Should -Be ([PingFailureType]::HostUnreachable)
        $failure.DisplayMessage | Should -Be 'Destination host unreachable'
    }

    It 'flags network level issues as network errors' {
        $failure = Get-PingFailure -Status ([System.Net.NetworkInformation.IPStatus]::BadRoute)

        $failure.Type | Should -Be ([PingFailureType]::NetworkError)
        $failure.DisplayMessage | Should -Be 'Bad network route'
    }

    It 'falls back to an unknown failure for unlisted statuses' {
        $failure = Get-PingFailure -Status ([System.Net.NetworkInformation.IPStatus]::Unknown)

        $failure.Type | Should -Be ([PingFailureType]::Unknown)
        $failure.DisplayMessage | Should -Be 'Unlisted error: Unknown'
    }

    It 'reports exceptions as network errors when no reply is available' {
        try {
            throw [System.Net.NetworkInformation.PingException]::new('Simulated failure')
        } catch {
            $failure = Get-PingFailure -ErrorRecord $_
        }

        $failure.Type | Should -Be ([PingFailureType]::NetworkError)
        $failure.OriginalStatus | Should -Be 'Exception'
        $failure.DisplayMessage | Should -Be 'Network error (Exception)'
    }

    It 'returns an indeterminate failure when no details are supplied' {
        $failure = Get-PingFailure

        $failure.Type | Should -Be ([PingFailureType]::Unknown)
        $failure.OriginalStatus | Should -Be 'NoReply'
        $failure.DisplayMessage | Should -Be 'Indeterminate error'
    }
}
