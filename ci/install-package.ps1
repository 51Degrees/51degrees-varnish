param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Name
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# The package job calls this with no build options, and no Varnish installed.
if (!$Name) {
    Write-Output "Not building the tarball, as this job has no Varnish"
    exit 0
}

$repo = (Get-Item $RepoName).FullName
$assets = "$PWD/assets"
$tarball = (Get-ChildItem package -Filter *.tar.gz | Select-Object -First 1).FullName
$build = New-Item -ItemType Directory -Force -Path "$repo/package-build"

Write-Output "Building $tarball in an empty folder"
tar xzf $tarball --strip-components=1 -C $build

# The tarball has no data files, so the IP Intelligence files go where its
# build looks for them by default, as fetch-assets.ps1 does for a clone. The
# module tests then use the ASN file and the examples the Lite file.
$ipIntelligence = New-Item -ItemType Directory -Force -Path "$build/cxx/data/ip-intelligence"
Copy-Item "$repo/cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi" $ipIntelligence
Copy-Item "$repo/cxx/data/ip-intelligence/51Degrees-LiteV41.ipi" $ipIntelligence

Push-Location $build
try {
    ./configure --with-config=test --with-datafile="$assets/51Degrees-LiteV4.1.hash"
    make
} finally {
    Pop-Location
}
