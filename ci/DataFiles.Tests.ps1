# Checks that CI gives the tests and examples data files it already has, so
# that none of them downloads one. Run it with Invoke-Pester
# ci/DataFiles.Tests.ps1.

BeforeAll {
    $script:Repo = (Get-Item $PSScriptRoot/..).FullName

    function Get-Text ([string]$Path) {
        Get-Content -Raw (Join-Path $script:Repo $Path)
    }

    # The paths in Makefile.am's default_ names, which the build downloads to
    # when the file is not there, below the build folder given.
    function Get-DefaultDataFiles ([string]$Build) {
        [regex]::Matches((Get-Text 'Makefile.am'),
            '(?m)^default_[a-z_]*datafile[a-z_]* = \$\(abs_top_builddir\)/(\S+)\r?$') |
            ForEach-Object { Join-Path $Build $_.Groups[1].Value }
    }

    # The data file names in the Dockerfile line that starts with $Start.
    function Get-DockerfileNames ([string]$Start) {
        $text = (Get-Text 'examples/curl/Dockerfile') -replace '\\\r?\n', ' '
        $line = ($text -split '\r?\n' | Where-Object { $_.StartsWith($Start) } | Select-Object -First 1)
        [regex]::Matches($line, '51Degrees-[A-Za-z0-9.\[\]]+') |
            ForEach-Object { $_.Value -replace '\[(.)\]', '$1' } | Sort-Object -Unique
    }
}

Describe 'Data files in CI' {
    It 'puts each file the build reads by default where it reads it, from the assets' {
        # fetch-assets.ps1 runs from the common-ci folder, where steps/
        # fetch-assets.ps1 leaves the assets in assets/.
        $repo = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'repo')
        New-Item -ItemType Directory -Path "$repo/ci", "$repo/cxx/data/device-detection",
            "$repo/cxx/data/ip-intelligence" | Out-Null
        Copy-Item (Join-Path $PSScriptRoot 'fetch-assets.ps1') "$repo/ci"
        $common = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'common')
        New-Item -ItemType Directory -Path "$common/steps" | Out-Null
        Set-Content "$common/steps/fetch-assets.ps1" @'
param([string[]]$Assets)
New-Item -ItemType Directory -Force -Path assets | Out-Null
foreach ($asset in $Assets) { Set-Content -LiteralPath "assets/$asset" $asset }
'@
        Push-Location $common
        try {
            & "$repo/ci/fetch-assets.ps1"
        } finally {
            Pop-Location
        }

        $defaults = @(Get-DefaultDataFiles $repo)
        $defaults.Count | Should -Be 3
        foreach ($file in $defaults) {
            $file | Should -Exist
        }
    }

    It 'names the larger Device Detection file from the assets in the integration tests' {
        Get-Text 'ci/run-integration-tests.ps1' |
            Should -Match '-MakeArguments "_51DEGREES_DD_PATH=\$assets/TAC-HashV41\.hash"'
    }

    It 'lets the Docker example use each data file it would download' {
        $downloaded = @(Get-DockerfileNames 'RUN sh cxx/data/get-data-files.sh')
        $downloaded | Should -Not -BeNullOrEmpty
        Get-DockerfileNames 'COPY default.vcl ' | Should -Be $downloaded
    }

    It 'gives the Docker example build the data files the job restored' {
        $text = Get-Text '.github/workflows/docker-example.yml'
        $text | Should -Match 'uses: actions/cache/restore@'
        $line = ($text -split '\r?\n' | Where-Object { $_ -match '^\s*for file in ' } | Select-Object -First 1)
        $copied = @([regex]::Matches($line, '51Degrees-[A-Za-z0-9.]+') | ForEach-Object Value | Sort-Object -Unique)
        $copied | Should -Be @(Get-DockerfileNames 'RUN sh cxx/data/get-data-files.sh')
        $text | Should -Match 'cp "assets/\$file" examples/curl/'
    }
}
