# Checks that invoke-apt-get.ps1 gives each apt-get run a time limit and runs
# it again when it fails. Run it with Invoke-Pester ci/invoke-apt-get.Tests.ps1.

BeforeAll {
    $script:Repo = (Get-Item $PSScriptRoot/..).FullName
    $script:Script = Join-Path $PSScriptRoot 'invoke-apt-get.ps1'
}

Describe 'invoke-apt-get.ps1' {
    BeforeEach {
        # The mock runs in Pester's scope, so what it records is global.
        $global:AptCalls = [System.Collections.Generic.List[object]]::new()
        $global:AptExitCodes = [System.Collections.Generic.Queue[int]]::new()
        $script:Calls = $global:AptCalls
        $script:ExitCodes = $global:AptExitCodes
        Mock sudo {
            $global:AptCalls.Add([string[]]$args)
            $global:LASTEXITCODE = $global:AptExitCodes.Count -gt 0 ? $global:AptExitCodes.Dequeue() : 0
        }
    }

    AfterEach {
        Remove-Variable -Scope Global -Name AptCalls, AptExitCodes -ErrorAction SilentlyContinue
    }

    It 'runs apt-get once under timeout, with the apt time limits, when it succeeds' {
        & $script:Script -Arguments 'install', 'make' -Seconds 300 | Out-Null

        $script:Calls.Count | Should -Be 1
        $call = $script:Calls[0]
        $call[0] | Should -Be 'timeout'
        $call | Should -Contain '300'
        $call | Should -Contain 'apt-get'
        $call | Should -Contain '-y'
        $call | Should -Contain 'Acquire::Retries=3'
        $call | Should -Contain 'Acquire::http::Timeout=30'
        $call | Should -Contain 'Acquire::https::Timeout=30'
        $call[-2..-1] | Should -Be @('install', 'make')
    }

    It 'runs apt-get again when the time limit ends it' {
        $script:ExitCodes.Enqueue(124)
        $script:ExitCodes.Enqueue(0)

        & $script:Script -Arguments 'update' | Out-Null

        $script:Calls.Count | Should -Be 2
        $script:Calls[1][-1] | Should -Be 'update'
    }

    It 'fails after the last attempt, having run apt-get that many times' {
        1..3 | ForEach-Object { $script:ExitCodes.Enqueue(100) }

        { & $script:Script -Arguments 'update' -Attempts 3 | Out-Null } |
            Should -Throw '*update*3 times*100*'
        $script:Calls.Count | Should -Be 3
    }

    It 'is the only way <_> runs apt-get' -ForEach @(
        'ci/setup-environment.ps1', 'ci/run-performance-tests.ps1'
    ) {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:Repo $_), [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
        $direct = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
                ($node.CommandElements | Where-Object { $_.Extent.Text -eq 'apt-get' })
        }, $true)
        $direct | Should -BeNullOrEmpty
        $ast.Extent.Text | Should -Match 'invoke-apt-get\.ps1'
    }
}
