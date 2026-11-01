param(
    [string]$VarnishVersion = "6.0.17"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# The publish workflow can call this more than once in a job.
if ((Get-Command varnishd -ErrorAction SilentlyContinue) -and
    ((varnishd -V 2>&1 | Out-String) -match "varnish-$([regex]::Escape($VarnishVersion)) ")) {
    Write-Output "Varnish $VarnishVersion is already installed"
    exit 0
}

# Where each version's source is published, with its SHA256. Releases from
# 6.0.17 and 8.0.1 onwards are GitHub releases, which show the SHA256 of each
# file. Older ones are on varnish.org, with their SHA256 on vinyl-cache.org's
# release pages.
$Sources = @{
    "6.0.6" = "https://www.varnish.org/downloads/varnish-6.0.6.tgz", "298476eaea36109845a7640fa578bf8a8a04124d2f1c9bc75e1d6ae2bd760b4a"
    "6.0.8" = "https://www.varnish.org/downloads/varnish-6.0.8.tgz", "5dd245b02840b9cd7ef8b10665d8172ef902dcc006f54f2c6801cbd71d1c68fe"
    "6.0.17" = "https://github.com/varnish/varnish/releases/download/varnish-6.0.17/varnish-6.0.17.tar.gz", "4530c81a91e9320d0b3a703f549765f530c870cf716917de31c9d62a9495079d"
    "6.0.18" = "https://github.com/varnish/varnish/releases/download/varnish-6.0.18/varnish-6.0.18.tar.gz", "4c3008d71544e3d0edc2aadc4fbd8d962aad700582544248030da2860131e514"
    "7.7.3" = "https://www.varnish.org/downloads/varnish-7.7.3.tgz", "e96eeafc4cfe2a558ed2fb54f1e22be3a3d995f46f8c00da545d583aaef80236"
    "8.0.1" = "https://github.com/varnish/varnish/releases/download/varnish-8.0.1/varnish-8.0.1.tar.gz", "04d1fa28d02080abb96b783062d30f4dd4ddf667ea93a0f0d37725d1301d7ea1"
    "9.0.4" = "https://github.com/varnish/varnish/releases/download/varnish-9.0.4/varnish-9.0.4.tar.gz", "766e91abf4d9ca7f00a88e105bc61109f1145983c09116db4228c9067fa2adc3"
    "9.1.0" = "https://github.com/varnish/varnish/releases/download/varnish-9.1.0/varnish-9.1.0.tar.gz", "fe615fa024c801d12928e7eea0e822ba93ab625a585841143c36ae02d5bcc37a"
}
if (!$Sources.ContainsKey($VarnishVersion)) {
    throw "Varnish $VarnishVersion has no source in $PSCommandPath"
}
$Url, $Sha256 = $Sources[$VarnishVersion]

# Varnish uses version 2 of the regular expression library from 7.0, and builds
# its test program with TLS support from 9.0.
$Major = ([version]$VarnishVersion).Major
$Packages = "make", "automake", "autotools-dev", "autoconf-archive", "libtool",
    "pkg-config", "cpio", "libedit-dev", "libncurses-dev", "python3-docutils"
$Packages += $Major -ge 7 ? "libpcre2-dev" : "libpcre3-dev"
if ($Major -ge 9) {
    $Packages += "libssl-dev"
}

Write-Output "Installing the packages needed to build Varnish $VarnishVersion"
sudo apt-get -y update
sudo apt-get -y install @Packages

$Source = New-Item -ItemType Directory -Force -Path ([IO.Path]::Combine([IO.Path]::GetTempPath(), "varnish-source"))
Push-Location $Source
try {
    Write-Output "Downloading Varnish $VarnishVersion from $Url"
    curl -fLsS --retry 5 -o varnish.tgz $Url
    $Actual = (Get-FileHash -Algorithm SHA256 varnish.tgz).Hash
    if ($Actual -ne $Sha256) {
        throw "The download has SHA256 $Actual, where $Sha256 was published"
    }

    Write-Output "Building Varnish $VarnishVersion"
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

varnishd -V
