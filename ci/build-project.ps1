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

Push-Location $PSScriptRoot/..
try {
    ./autogen.sh
    $configure = @('--with-config=test')
    if ($ClangVersion) {
        $configure += "CC=clang-$ClangVersion"
    }
    ./configure @configure
    make
} finally {
    Pop-Location
}
