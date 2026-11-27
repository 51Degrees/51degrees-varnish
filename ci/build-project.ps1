param(
    # The major version of clang that setup-environment.ps1 installed, to
    # build the modules with in place of the default gcc.
    [string]$ClangVersion
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# A warning stops 51Degrees' own builds. Until the shared workflows set this
# for every job, the build scripts set it.
if (!$env:_51DEGREES_WARNINGS_AS_ERRORS) {
    $env:_51DEGREES_WARNINGS_AS_ERRORS = 'true'
}

$repo = (Get-Item $PSScriptRoot/..).FullName
$configure = @('--with-config=test')
if ($ClangVersion) {
    $configure += "CC=clang-$ClangVersion"
}

Push-Location $repo
try {
    ./autogen.sh
    ./configure @configure
    make
    # The release tarball has only the files the Makefile.am lists name, so a
    # header the clone has and they leave out builds here but not from the
    # tarball. make dist succeeds either way, so the tarball is built too.
    make dist distdir=dist-check
} finally {
    Pop-Location
}

$build = Join-Path ([IO.Path]::GetTempPath()) dist-check
Remove-Item -Recurse -Force $build -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $build | Out-Null
tar xzf "$repo/dist-check.tar.gz" --strip-components=1 -C $build
Remove-Item "$repo/dist-check.tar.gz"

Write-Output "Building the make dist tarball in $build"
Push-Location $build
try {
    # The tarball has no data files, and configure needs the one it bundles.
    ./configure @configure --with-datafile="$repo/cxx/data/device-detection/51Degrees-LiteV4.1.hash"
    make
} finally {
    Pop-Location
}
