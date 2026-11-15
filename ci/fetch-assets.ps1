param (
    [string]$DeviceDetection,
    [string]$DeviceDetectionUrl
)
$ErrorActionPreference = "Stop"

# Every data file the tests read is an asset, which the run caches once, so a
# test job restores the files rather than downloading them.
./steps/fetch-assets.ps1 -DeviceDetection:$DeviceDetection -DeviceDetectionUrl:$DeviceDetectionUrl -Assets "TAC-HashV41.hash", "51Degrees-LiteV4.1.hash", "20000 Evidence Records.yml", "51Degrees-IPIV4AsnIpiV41.ipi"

# The IP Intelligence tests read the ASN file where a fresh clone's data
# submodule keeps it, which is where configure looks by default.
Copy-Item "assets/51Degrees-IPIV4AsnIpiV41.ipi" "$PSScriptRoot/../cxx/data/ip-intelligence"
