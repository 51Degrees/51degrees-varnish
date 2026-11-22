# Checks the names this repository's build, tests, examples and CI read or
# set. Each one 51Degrees defines starts _51DEGREES_, and the others are names
# another tool defines. Run it with Invoke-Pester ci/Names.Tests.ps1.

BeforeAll {
    $script:Repo = (Get-Item $PSScriptRoot/..).FullName
    $script:Ours = '^_51DEGREES_[A-Z0-9_]+$'

    # Names another tool defines, which the CI scripts read as that tool
    # requires.
    $script:ToolNames = 'PATH', 'CHROMEWEBDRIVER', 'GECKOWEBDRIVER'

    function Get-Text ([string]$Path) {
        Get-Content -Raw (Join-Path $script:Repo $Path)
    }

    function Get-Names ([string]$Path, [string]$Pattern) {
        [regex]::Matches((Get-Text $Path), $Pattern, 'Multiline') |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    }

    function Get-Ast ([string]$Path) {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:Repo $Path), [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
        $ast
    }

    $script:CiScripts = Get-ChildItem "$script:Repo/ci" -Filter *.ps1 |
        Where-Object Name -notlike '*.Tests.ps1' |
        ForEach-Object { "ci/$($_.Name)" }
}

Describe 'Names read and set' {
    It 'gives each tracked file only names that start with the underscore' {
        $found = git -C $script:Repo grep -I -n -E '(^|[^A-Za-z0-9_])[5]1DEGREES_' -- . ':!cxx'
        $found | Should -BeNullOrEmpty
    }

    It 'reads the data files for make check from _51DEGREES_ names in <_>' -ForEach @(
        'Makefile.am', 'src/dd/Makefile.am', 'src/ipi/Makefile.am'
    ) {
        $names = @(Get-Names $_ '\$\(or \$\(([^)]+)\)')
        $names | Should -Not -BeNullOrEmpty
        $names | ForEach-Object { $_ | Should -Match $script:Ours }
    }

    It 'names both data files in the top Makefile.am' {
        $names = @(Get-Names 'Makefile.am' '\$\(or \$\(([^)]+)\)')
        $names | Should -Contain '_51DEGREES_DD_PATH'
        $names | Should -Contain '_51DEGREES_IPI_PATH'
    }

    It 'reads and sets only _51DEGREES_ and tool names in the CI scripts' {
        foreach ($script in $script:CiScripts) {
            foreach ($name in @(Get-Names $script '\$env:([A-Za-z_][A-Za-z0-9_]*)')) {
                if ($name -notin $script:ToolNames) {
                    $name | Should -Match $script:Ours -Because "$script reads or sets it"
                }
            }
        }
    }

    It 'gives make only _51DEGREES_ names in the CI scripts' {
        $given = foreach ($script in $script:CiScripts) {
            $commands = (Get-Ast $script).FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst]
            }, $true)
            foreach ($command in $commands) {
                $elements = $command.CommandElements
                for ($i = 0; $i -lt $elements.Count - 1; $i++) {
                    if ($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and
                        $elements[$i].ParameterName -eq 'MakeArguments') {
                        $elements[$i + 1].FindAll({
                            param($node)
                            $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                            $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
                        }, $true) | ForEach-Object { $_.Value }
                    }
                }
            }
        }
        $given | Should -Not -BeNullOrEmpty
        foreach ($argument in $given) {
            ($argument -split '=', 2)[0] | Should -Match $script:Ours
        }
    }

    It 'takes no key or address in ci/fetch-assets.ps1' {
        $ast = Get-Ast 'ci/fetch-assets.ps1'
        @($ast.ParamBlock.Parameters).Count | Should -Be 0
        $passed = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandParameterAst]
        }, $true) | ForEach-Object { $_.ParameterName }
        $passed | Should -Be @('Assets')
    }

    It 'reads only _51DEGREES_ names from the environment in the performance test' {
        $names = @(Get-Names 'tests/performance/runPerf.sh' '\$\{([A-Za-z_][A-Za-z0-9_]*):[-?=+]')
        $names | Should -Not -BeNullOrEmpty
        $names | ForEach-Object { $_ | Should -Match $script:Ours }
    }

    It 'takes the engine and the build folder of the performance test as arguments' -Skip:(!$IsLinux) {
        $output = bash "$script:Repo/tests/performance/runPerf.sh" 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 2
        $output | Should -Match 'Usage: .*runPerf\.sh hash\|ipi '
    }

    It 'reads no name from the environment in the browser test' {
        $test = 'tests/examples/jsExample/cdn.test.js'
        if (Test-Path (Join-Path $script:Repo $test)) {
            Get-Names $test 'process\.env\.([A-Za-z_][A-Za-z0-9_]*)' | Should -BeNullOrEmpty
        }
    }

    It 'names the secrets CI needs with _51DEGREES_ in ci/README.md' {
        $names = @(Get-Names 'ci/README.md' '^\* `([^`]+)` - ')
        $names | Should -Not -BeNullOrEmpty
        $names | ForEach-Object { $_ | Should -Match $script:Ours }
    }

    It 'gives the Docker example only _51DEGREES_ build arguments' {
        $names = @(Get-Names 'examples/curl/Dockerfile' '^ARG\s+([A-Za-z_][A-Za-z0-9_]*)')
        $names | Should -Not -BeNullOrEmpty
        $names | ForEach-Object { $_ | Should -Match $script:Ours }

        $documented = @(Get-Names 'examples/curl/README.md' '--build-arg\s+([A-Za-z_][A-Za-z0-9_]*)=') +
            @(Get-Names '.github/workflows/docker-example.yml' '--build-arg\s+"?([A-Za-z_][A-Za-z0-9_]*)=')
        $documented | Should -Not -BeNullOrEmpty
        $documented | ForEach-Object { $_ | Should -BeIn $names }
    }

    It 'sets only _51DEGREES_ names in the env blocks of <_.Name>' -ForEach @(
        Get-ChildItem "$PSScriptRoot/../.github/workflows" -Filter *.yml
    ) {
        # The keys one level under each env: line.
        $lines = Get-Content $_.FullName
        $names = for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^(\s*)env:\s*$') {
                $indent = $Matches[1].Length
                $keyIndent = $null
                for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                    if ($lines[$j] -match '^\s*(#.*)?$') { continue }
                    $lines[$j] -match '^(\s*)' | Out-Null
                    $lineIndent = $Matches[1].Length
                    if ($lineIndent -le $indent) { break }
                    $keyIndent ??= $lineIndent
                    if ($lineIndent -eq $keyIndent -and $lines[$j] -match '^\s*([A-Za-z_][A-Za-z0-9_]*):') {
                        $Matches[1]
                    }
                }
            }
        }
        $names | ForEach-Object { $_ | Should -Match $script:Ours }
    }
}
