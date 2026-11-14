param(
    # Every entry of options.json.
    [Parameter(Mandatory)][object[]]$Options,
    # The files the pull request changes, less documentation.
    [string[]]$ChangedFiles
)
# Chooses the options.json entries a pull request is built on, for common-ci's
# steps/select-options.ps1. The branch itself and a release build every entry.
#
# Every entry that tests a Varnish or Vinyl Cache version runs. The two that
# measure performance build and test the same as the Varnish 9.1.0 entry
# first, so they are left to the branch and release builds.

foreach ($entry in $Options) {
    if ($entry.RunPerformance) {
        Write-Host "$($entry.Name) measures performance, which is left to the branch and release builds"
        continue
    }
    Write-Host "$($entry.Name) runs"
    $entry
}
