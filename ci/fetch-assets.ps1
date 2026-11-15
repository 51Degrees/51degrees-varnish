param (
    [string]$DeviceDetection,
    [string]$DeviceDetectionUrl
)
$ErrorActionPreference = "Stop"

# Every data file the tests read is an asset, which the run caches once, so a
# test job restores the files rather than downloading them.
./steps/fetch-assets.ps1 -DeviceDetection:$DeviceDetection -DeviceDetectionUrl:$DeviceDetectionUrl -Assets "TAC-HashV41.hash", "51Degrees-LiteV4.1.hash", "20000 Evidence Records.yml", "51Degrees-IPIV4AsnIpiV41.ipi", "51Degrees-LiteIpiV41.ipi"

# The unit tests read the Lite Hash file, the IP Intelligence module tests the
# ASN file, and the IP Intelligence and mixed examples the Lite IP Intelligence
# file, where a fresh clone's data submodule keeps them, which is where the
# build looks by default.
Copy-Item "assets/51Degrees-LiteV4.1.hash" "$PSScriptRoot/../cxx/data/device-detection"
$ipIntelligence = "$PSScriptRoot/../cxx/data/ip-intelligence"
Copy-Item "assets/51Degrees-IPIV4AsnIpiV41.ipi" $ipIntelligence
Copy-Item "assets/51Degrees-LiteIpiV41.ipi" "$ipIntelligence/51Degrees-LiteV41.ipi"
