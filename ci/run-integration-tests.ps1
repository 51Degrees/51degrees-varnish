param(
    [string]$Name = "integration",
    [bool]$MemCheck = $False,
    [string]$VinylVersion
)
$ErrorActionPreference = "Stop"

# Vinyl Cache's program has its own name.
$Daemon = $VinylVersion ? "vinyld" : "varnishd"

# A library built with the address sanitizer only loads through make mem-check,
# which the unit tests have already run.
if ($MemCheck) {
    Write-Output "Not repeating the tests with the larger data file"
    exit 0
}

$repo = (Get-Item $PSScriptRoot/..).FullName
$assets = "$PWD/assets"

# Repeat the tests with the larger data file, in the folder install-package.ps1
# built from the release tarball if there is one. That build names the ASN
# file for the module tests, so the IP Intelligence examples are given the Lite
# file that fetch-assets.ps1 copies beside it, as a default build gives them.
$build = (Test-Path "$repo/package-build") ? "$repo/package-build" : $repo
& $PSScriptRoot/run-vtc-tests.ps1 -BuildPath $build -SuiteName $Name `
    -ResultsFile "$repo/test-results/integration/$Name.xml" `
    -MakeArguments "datafile=$assets/TAC-HashV41.hash", `
        "example_datafile_ipi=$repo/cxx/data/ip-intelligence/51Degrees-LiteV41.ipi"
$testsExit = $LASTEXITCODE

Write-Output "Running the browser test of the JavaScript example"
$browserExit = 0
$work = New-Item -ItemType Directory -Force -Path "$repo/test-results/browser"
$vcl = "$work/javascript.vcl"
(Get-Content -Raw "$repo/examples/hash/jsExample/javascript.vcl").Replace(
    "/etc/varnish/51Degrees-LiteV4.1.hash", "$assets/TAC-HashV41.hash") | Set-Content $vcl
& $Daemon -n "$work/varnish" -P "$work/varnish.pid" -a 127.0.0.1:8888 -f $vcl -p "vmod_path=$build/src/dd/.libs"
if ($LASTEXITCODE -ne 0) {
    Write-Output "::error::Varnish did not start for the browser test"
    $browserExit = 1
} else {
    $page = Start-Process python3 -PassThru -ArgumentList "-m", "http.server", "8889", "--directory", "$repo/examples/hash/jsExample"
    Push-Location "$repo/tests/examples/jsExample"
    try {
        $env:PATH = "$($env:PATH):$($env:CHROMEWEBDRIVER):$($env:GECKOWEBDRIVER)"
        npm install
        npm test
        # A failure of the browser test fails the job.
        $browserExit = $LASTEXITCODE
        if ($browserExit -ne 0) {
            Write-Output "::error::The browser test of the JavaScript example failed"
        }
    } finally {
        Pop-Location
        Stop-Process -InputObject $page
        # The daemon holds a lock on the file which .NET will not read past.
        sh -c "kill `$(cat '$work/varnish.pid')"
    }
}
exit ($testsExit -ne 0 -or $browserExit -ne 0) ? 1 : 0
