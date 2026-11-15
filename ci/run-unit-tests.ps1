param(
    [string]$Name = "unit",
    [bool]$MemCheck = $False
)
$ErrorActionPreference = "Stop"

$repo = (Get-Item $PSScriptRoot/..).FullName

# The tests run with nothing set, as in a fresh clone, on the free files that
# fetch-assets.ps1 copies to where the build looks for them by default.
& $PSScriptRoot/run-vtc-tests.ps1 -BuildPath $repo -SuiteName $Name `
    -ResultsFile "$repo/test-results/unit/$Name.xml" `
    -Target ($MemCheck ? "mem-check" : "check")
exit $LASTEXITCODE
