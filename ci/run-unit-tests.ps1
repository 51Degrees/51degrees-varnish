param(
    [string]$Name = "unit",
    [bool]$MemCheck = $False,
    # How many times the address sanitizer tests run. The child crash this
    # looks for failed about half the passes of the whole suite.
    [int]$MemCheckPasses = 16,
    # Cores runs with Varnish's signal handler and keeps a core file of each
    # crash. NoAltStack stops the address sanitizer giving each thread an
    # alternate signal stack of its own.
    [string]$MemCheckMode = "Cores"
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

if (!$MemCheck) {
    # The tests run with nothing set, as in a fresh clone, on the free files
    # that fetch-assets.ps1 copies to where the build looks for them by
    # default.
    & $PSScriptRoot/run-vtc-tests.ps1 -BuildPath $repo -SuiteName $Name `
        -ResultsFile "$repo/test-results/unit/$Name.xml" `
        -Target "check"
    exit (($LASTEXITCODE -ne 0 -or $scriptTestsFailed) ? 1 : 0)
}

# The address sanitizer tests run many times so that a child that crashes
# now and then is caught, and each crash is reported.
#
# Core files go to /tmp/cores. The address sanitizer stops core files unless
# disable_coredump=0. gdb prints the signal, every thread and every thread's
# stack from each core.
& $PSScriptRoot/invoke-apt-get.ps1 -Arguments @('install', 'gdb')
sudo mkdir -p /tmp/cores /tmp/cores/done /tmp/asan
sudo chmod -R 1777 /tmp/cores /tmp/asan
Write-Output "Core pattern was $(Get-Content /proc/sys/kernel/core_pattern)"
sudo sysctl -w kernel.core_pattern=/tmp/cores/core.%e.%p.%t
sudo prlimit --pid $PID --core=unlimited:unlimited
Write-Output "Core limit: $(prlimit --pid $PID --core --output SOFT,HARD --noheadings)"

$daemon = (Get-Command varnishd -ErrorAction SilentlyContinue).Source
if (!$daemon) { $daemon = (Get-Command vinyld).Source }

function Show-Crashes([int]$Pass) {
    $cores = @(Get-ChildItem /tmp/cores -File -Filter 'core.*')
    foreach ($core in $cores) {
        Write-Host "::group::Pass $Pass core $($core.Name), the signal and every thread's stack"
        gdb -batch -nx `
            -ex 'p $_siginfo' `
            -ex 'info threads' `
            -ex 'thread apply all bt' `
            -ex 'bt full' `
            -ex 'info registers' `
            -ex 'x/4i $pc' `
            $daemon $core.FullName 2>&1 | ForEach-Object { Write-Host $_ }
        Write-Host "::endgroup::"
        Move-Item $core.FullName /tmp/cores/done/
    }
    $logs = @(Get-ChildItem /tmp/asan -File)
    foreach ($log in $logs) {
        Write-Host "::group::Pass $Pass address sanitizer report $($log.Name)"
        Get-Content $log.FullName | ForEach-Object { Write-Host $_ }
        Write-Host "::endgroup::"
        Remove-Item $log.FullName
    }
    $kernel = sudo dmesg 2>&1 | Select-String -Pattern 'segfault|general protection|traps:|varnish|cache-' |
        Select-Object -Last 10
    if ($kernel) {
        Write-Host "Kernel messages after pass ${Pass}:"
        $kernel | ForEach-Object { Write-Host "  $_" }
    }
    return $cores.Count
}

$asanLibrary = (& cc '-print-file-name=libasan.so').Trim()
if (!(Test-Path $asanLibrary)) { throw "The address sanitizer library was not found: $asanLibrary" }
$options = "detect_leaks=0:detect_odr_violation=0:log_path=/tmp/asan/asan:disable_coredump=0"
if ($MemCheckMode -eq "NoAltStack") { $options += ":use_sigaltstack=0" }
$failedPasses = @()
$crashes = 0

# The first pass builds both modules with the address sanitizer and runs the
# tests, as the release build does.
& $PSScriptRoot/run-vtc-tests.ps1 -BuildPath $repo -SuiteName "$Name-1" `
    -ResultsFile "$repo/test-results/unit/$Name-1.xml" -Target "mem-check"
if ($LASTEXITCODE -ne 0) { $failedPasses += 1 }
$crashes += Show-Crashes -Pass 1

for ($pass = 2; $pass -le $MemCheckPasses; $pass++) {
    Write-Output "Pass $pass with ASAN_OPTIONS=$options"
    $env:LD_PRELOAD = $asanLibrary
    $env:ASAN_OPTIONS = $options
    try {
        & $PSScriptRoot/run-vtc-tests.ps1 -BuildPath $repo -SuiteName "$Name-$pass" `
            -ResultsFile "$repo/test-results/unit/$Name-$pass.xml" -Target "check"
        $passExit = $LASTEXITCODE
    } finally {
        Remove-Item Env:LD_PRELOAD
        Remove-Item Env:ASAN_OPTIONS
    }
    if ($passExit -ne 0) { $failedPasses += $pass }
    $crashes += Show-Crashes -Pass $pass
}

Write-Output "Mode $MemCheckMode, passes run: $MemCheckPasses, passes failed: $($failedPasses.Count) ($($failedPasses -join ', ')), core files: $crashes"
exit (($failedPasses.Count -gt 0 -or $scriptTestsFailed) ? 1 : 0)
