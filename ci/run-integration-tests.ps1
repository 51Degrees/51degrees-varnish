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
# built from the release tarball if there is one. The IP Intelligence tests
# and examples use the files the build looks for by default.
$build = (Test-Path "$repo/package-build") ? "$repo/package-build" : $repo
& $PSScriptRoot/run-vtc-tests.ps1 -BuildPath $build -SuiteName $Name `
    -ResultsFile "$repo/test-results/integration/$Name.xml" `
    -MakeArguments "_51DEGREES_DD_PATH=$assets/TAC-HashV41.hash"
$testsExit = $LASTEXITCODE

Write-Output "Running the browser test of the JavaScript example"
$browserExit = 0
$work = New-Item -ItemType Directory -Force -Path "$repo/test-results/browser"

# The browser test is the ModuleJavaScript category of the shared browser test
# suite, checked out beside this repository as the API repositories do. The
# suite finds and starts Chrome, Firefox and their drivers, so nothing here
# does. It is built before Varnish starts, so the wait for the page below
# covers the page alone.
$suite = Join-Path (Split-Path $repo) "selenium-api-tests"
if (-not (Test-Path $suite)) {
    git clone --depth 1 https://github.com/51Degrees/selenium-api-tests.git $suite
}
git -C $suite log -1 --format="selenium-api-tests at %H %s"
if ($LASTEXITCODE -ne 0) {
    Write-Output "::error::The shared browser test suite was not checked out"
    $browserExit = 1
} else {
    dotnet build $suite -c Release
}
if ($browserExit -eq 0 -and $LASTEXITCODE -ne 0) {
    Write-Output "::error::The shared browser test suite did not build"
    $browserExit = 1
}

if ($browserExit -eq 0) {
    $vcl = "$work/javascript.vcl"
    (Get-Content -Raw "$repo/examples/hash/jsExample/javascript.vcl").Replace(
        "/etc/varnish/51Degrees-LiteV4.1.hash", "$assets/TAC-HashV41.hash") | Set-Content $vcl
    & $Daemon -n "$work/varnish" -P "$work/varnish.pid" -a 127.0.0.1:8888 -f $vcl -p "vmod_path=$build/src/dd/.libs"
    if ($LASTEXITCODE -ne 0) {
        Write-Output "::error::Varnish did not start for the browser test"
        $browserExit = 1
    }
}

if ($browserExit -eq 0) {
    # Chrome keeps no cookie for a page opened from a file, so the page is
    # served over HTTP for the module's JavaScript to pass its evidence on.
    $page = Start-Process python3 -PassThru -ArgumentList "-m", "http.server", "8889", "--directory", "$repo/examples/hash/jsExample"
    try {
        $env:_51DEGREES_EXAMPLE_URL = "http://localhost:8889/index.html"
        # Seconds the page server has to answer before the tests start.
        $pageWaitSeconds = 30
        curl -sS -o /dev/null --retry $pageWaitSeconds --retry-delay 1 --retry-connrefused $env:_51DEGREES_EXAMPLE_URL
        if ($LASTEXITCODE -ne 0) {
            Write-Output "::error::The JavaScript example's page was not served within $pageWaitSeconds s"
            $browserExit = 1
        } else {
            $trx = "module-javascript.trx"
            dotnet test $suite -c Release --no-build --filter TestCategory=ModuleJavaScript `
                --logger "trx;LogFileName=$trx" --logger "console;verbosity=normal" `
                --results-directory $work
            $testExit = $LASTEXITCODE
            # dotnet test passes a run that found no test, or whose tests were
            # skipped, so the results file decides, and every test in it must
            # have passed.
            $counters = $null
            if (Test-Path "$work/$trx") {
                $counters = ([xml](Get-Content -Raw "$work/$trx")).TestRun.ResultSummary.Counters
            }
            if ($counters) {
                Write-Output "ModuleJavaScript: $($counters.passed) of $($counters.total) passed"
            }
            if ($testExit -ne 0 -or -not $counters -or [int]$counters.total -eq 0 -or
                $counters.passed -ne $counters.total) {
                Write-Output "::error::The browser test of the JavaScript example failed"
                $browserExit = 1
            }
        }
    } finally {
        Remove-Item Env:_51DEGREES_EXAMPLE_URL -ErrorAction SilentlyContinue
        Stop-Process -InputObject $page
        # The daemon holds a lock on the file which .NET will not read past.
        sh -c "kill `$(cat '$work/varnish.pid')"
    }
}
exit ($testsExit -ne 0 -or $browserExit -ne 0) ? 1 : 0
