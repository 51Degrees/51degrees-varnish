param (
    [string]$DeviceDetection,
    [string]$DeviceDetectionUrl
)
$ErrorActionPreference = "Stop"

./steps/fetch-assets.ps1 -DeviceDetection:$DeviceDetection -DeviceDetectionUrl:$DeviceDetectionUrl -Assets "TAC-HashV41.hash", "51Degrees-LiteV4.1.hash", "20000 Evidence Records.yml"

# The IP Intelligence tests use the ASN file in the data submodule, which holds
# a link to the file rather than the file.
$global:LASTEXITCODE = 0
& "$PSScriptRoot/../cxx/data/get-data-files.ps1" 51Degrees-IPIV4AsnIpiV41.ipi
if ($LASTEXITCODE -ne 0) {
    throw "The ASN data file was not downloaded"
}
