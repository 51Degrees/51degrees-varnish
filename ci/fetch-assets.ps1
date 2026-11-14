param (
    [string]$DeviceDetection,
    [string]$DeviceDetectionUrl
)
$ErrorActionPreference = "Stop"

./steps/fetch-assets.ps1 -DeviceDetection:$DeviceDetection -DeviceDetectionUrl:$DeviceDetectionUrl -Assets "TAC-HashV41.hash", "51Degrees-LiteV4.1.hash", "20000 Evidence Records.yml"

# The IP Intelligence module tests use the ASN file, and the IP Intelligence
# and mixed examples the Lite file. The data submodule holds a link to each
# rather than the file.
$global:LASTEXITCODE = 0
& "$PSScriptRoot/../cxx/data/get-data-files.ps1" 51Degrees-IPIV4AsnIpiV41.ipi 51Degrees-LiteV41.ipi
if ($LASTEXITCODE -ne 0) {
    throw "The IP Intelligence data files were not downloaded"
}
