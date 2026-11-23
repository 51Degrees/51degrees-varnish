param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Name = "performance"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$repo = (Get-Item $RepoName).FullName
$assets = "$PWD/assets"
$common = $PWD

# The module folder install-package.ps1 built from the release tarball if there
# is one, otherwise the one build-project.ps1 built.
$modules = (Test-Path "$repo/package-build") ? "$repo/package-build" : $repo

# Configurations named _IPI measure IP Intelligence, and the others device
# detection, so each has its own graph. IP Intelligence runs on the ASN file
# in cxx/data, which runPerf.sh uses when no file is named.
if ($Name -like '*_IPI') {
    $engine = "ipi"
} else {
    $engine = "hash"
    $env:_51DEGREES_DD_PATH = "$assets/TAC-HashV41.hash"
    $env:_51DEGREES_EVIDENCE_YAML = "$assets/20000 Evidence Records.yml"
}

# A run that failed writes no results and only warns, because failing here would
# fail the Test job and stop the night's release.
try {
    Write-Output "Installing what the benchmark tool needs"
    sudo apt-get -y install cmake libapr1-dev libaprutil1-dev

    $build = New-Item -ItemType Directory -Force -Path "$repo/tests/performance/build"
    Push-Location $build
    try {
        cmake ..
        cmake --build .
        ./runPerf.sh $engine $modules
    } finally {
        Pop-Location
    }

    & $common/steps/publish-performance-results.ps1 -SourceFile "$build/results.json" -Name $Name -RepoName $RepoName
} catch {
    Write-Warning "No results for ${Name}: $_"
    $global:LASTEXITCODE = 0
}
