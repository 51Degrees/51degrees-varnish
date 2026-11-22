param(
    [string]$Name = "unit",
    [bool]$MemCheck = $False
)
$ErrorActionPreference = "Stop"

$repo = (Get-Item $PSScriptRoot/..).FullName

# The tests of the CI scripts run in a process of their own, as Pester
# writes into the scope that calls it.
Write-Host "Running the CI script tests"
Push-Location $repo
try {
    pwsh -NoProfile -Command "`$run = New-PesterConfiguration; `$run.Run.Path = 'ci'; `$run.Run.Exit = `$true; `$run.Output.Verbosity = 'Detailed'; Invoke-Pester -Configuration `$run"
    $scriptTestsFailed = $LASTEXITCODE -ne 0
} finally {
    Pop-Location
}

# The tests run with nothing set, as in a fresh clone, on the free files that
# fetch-assets.ps1 copies to where the build looks for them by default.
& $PSScriptRoot/run-vtc-tests.ps1 -BuildPath $repo -SuiteName $Name `
    -ResultsFile "$repo/test-results/unit/$Name.xml" `
    -Target ($MemCheck ? "mem-check" : "check")
exit (($LASTEXITCODE -ne 0 -or $scriptTestsFailed) ? 1 : 0)
