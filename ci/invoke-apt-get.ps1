<#
.SYNOPSIS
    Runs apt-get with a time limit on each attempt, and runs it again when it
    fails.

.DESCRIPTION
    apt-get can wait without end on a package mirror that stops sending,
    so each attempt runs under timeout, which ends it after Seconds. apt's own
    retry and connection time limits are set as well. When an attempt fails,
    for any reason, it runs again, up to Attempts in all, and then the script
    fails with apt-get's last exit code.

.PARAMETER Arguments
    What apt-get is to do, such as update, or install and the package names.
    The script adds -y.

.PARAMETER Attempts
    How many times apt-get runs before the script fails.

.PARAMETER Seconds
    How long each attempt may take.
#>
param(
    [Parameter(Mandatory)][string[]]$Arguments,
    [int]$Attempts = 3,
    [int]$Seconds = 300
)
$ErrorActionPreference = "Stop"
# The exit code decides whether apt-get runs again.
$PSNativeCommandUseErrorActionPreference = $false

$options = '-o', 'Acquire::Retries=3', '-o', 'Acquire::http::Timeout=30', '-o', 'Acquire::https::Timeout=30'

for ($attempt = 1; ; $attempt++) {
    sudo timeout --kill-after=30 $Seconds apt-get -y @options @Arguments
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        return
    }
    if ($attempt -ge $Attempts) {
        throw "apt-get $($Arguments -join ' ') failed $Attempts times, the last with exit code $code"
    }
    # timeout exits with 124 when the time limit ends apt-get.
    Write-Output "apt-get $($Arguments[0]) ended with exit code $code, so it runs again, attempt $($attempt + 1) of $Attempts"
}
