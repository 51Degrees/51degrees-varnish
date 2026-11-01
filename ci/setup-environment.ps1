param(
    [string]$VarnishVersion = "6.0.18",
    [string]$VinylVersion
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# VinylVersion builds Vinyl Cache in place of Varnish Cache, as their 9.x
# releases are different code.
if ($VinylVersion) {
    $Project = "Vinyl Cache"
    $Version = $VinylVersion
    $Daemon = "vinyld"
    # Each version's source, with the SHA256 on its vinyl-cache.org release page.
    $Sources = @{
        "9.0.2" = "https://vinyl-cache.org/downloads/vinyl-cache-9.0.2.tgz", "7e483062985c67a9f2901fa20f713097c7001d697549f4467cbf8123eb6c69c7"
        "9.1.0" = "https://vinyl-cache.org/downloads/vinyl-cache-9.1.0.tgz", "3840a06dd0cd212fd1e3beeb8b086dbd7c35ca31cfe1962fe2586363a63410aa"
    }
} else {
    $Project = "Varnish"
    $Version = $VarnishVersion
    $Daemon = "varnishd"
    # Each version's source is a GitHub release, which shows the SHA256 of each
    # file.
    $Sources = @{
        "6.0.18" = "https://github.com/varnish/varnish/releases/download/varnish-6.0.18/varnish-6.0.18.tar.gz", "4c3008d71544e3d0edc2aadc4fbd8d962aad700582544248030da2860131e514"
        "9.0.4" = "https://github.com/varnish/varnish/releases/download/varnish-9.0.4/varnish-9.0.4.tar.gz", "766e91abf4d9ca7f00a88e105bc61109f1145983c09116db4228c9067fa2adc3"
        "9.1.0" = "https://github.com/varnish/varnish/releases/download/varnish-9.1.0/varnish-9.1.0.tar.gz", "fe615fa024c801d12928e7eea0e822ba93ab625a585841143c36ae02d5bcc37a"
    }
}

# The publish workflow can call this more than once in a job.
if ((Get-Command $Daemon -ErrorAction SilentlyContinue) -and
    ((& $Daemon -V 2>&1 | Out-String) -match "-$([regex]::Escape($Version)) ")) {
    Write-Output "$Project $Version is already installed"
    exit 0
}

if (!$Sources.ContainsKey($Version)) {
    throw "$Project $Version has no source in $PSCommandPath"
}
$Url, $Sha256 = $Sources[$Version]

# Version 2 of the regular expression library is used from 7.0, and Varnish
# Cache builds its test program with TLS support from 9.0.
$Major = ([version]$Version).Major
$Packages = "make", "automake", "autotools-dev", "autoconf-archive", "libtool",
    "pkg-config", "cpio", "libedit-dev", "libncurses-dev", "python3-docutils"
$Packages += $Major -ge 7 ? "libpcre2-dev" : "libpcre3-dev"
if (!$VinylVersion -and $Major -ge 9) {
    $Packages += "libssl-dev"
}

Write-Output "Installing the packages needed to build $Project $Version"
sudo apt-get -y update
sudo apt-get -y install @Packages

$Source = New-Item -ItemType Directory -Force -Path ([IO.Path]::Combine([IO.Path]::GetTempPath(), "varnish-source"))
Push-Location $Source
try {
    Write-Output "Downloading $Project $Version from $Url"
    curl -fLsS --retry 5 -o varnish.tgz $Url
    $Actual = (Get-FileHash -Algorithm SHA256 varnish.tgz).Hash
    if ($Actual -ne $Sha256) {
        throw "The download has SHA256 $Actual, where $Sha256 was published"
    }

    Write-Output "Building $Project $Version"
    New-Item -ItemType Directory -Path build | Out-Null
    tar xzf varnish.tgz --strip-components=1 -C build
    Push-Location build
    try {
        ./configure --without-jemalloc --with-sphinx-build=true
        make -j ([Environment]::ProcessorCount)
        sudo make install
        sudo ldconfig
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
    Remove-Item -Recurse -Force $Source
}

& $Daemon -V
