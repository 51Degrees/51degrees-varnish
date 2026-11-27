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

    $script:DataFileNames = '51Degrees-[A-Za-z0-9.]+\.(hash|ipi)'

    function Get-Names ([string]$Text) {
        @([regex]::Matches($Text, $script:DataFileNames) | ForEach-Object Value |
            Sort-Object -Unique)
    }

    # The Dockerfile's RUN step that puts the data files in place, joined onto
    # one line, without RUN and its bind mount, and the folder it mounts.
    function Get-DataFileStep {
        $text = (Get-Text 'examples/curl/Dockerfile') -replace '\\\r?\n', ' '
        $line = $text -split '\r?\n' |
            Where-Object { $_ -match '^RUN --mount=type=bind,target=(\S+) (.*)$' } |
            Select-Object -First 1
        $line | Should -Not -BeNullOrEmpty -Because 'the Dockerfile reads the data files through a bind mount'
        $null = $line -match '^RUN --mount=type=bind,target=(\S+) (.*)$'
        @{ Mount = $Matches[1]; Script = $Matches[2] }
    }

    # The default the Dockerfile gives _51DEGREES_DOWNLOAD_DATA_FILES.
    function Get-DownloadDefault {
        $match = [regex]::Match((Get-Text 'examples/curl/Dockerfile'),
            '(?m)^ARG _51DEGREES_DOWNLOAD_DATA_FILES=(\S*)\r?$')
        $match.Success | Should -BeTrue -Because 'the Dockerfile declares _51DEGREES_DOWNLOAD_DATA_FILES'
        $match.Groups[1].Value
    }

    # Runs the data file step in a folder of its own, with the given files
    # beside the Dockerfile and _51DEGREES_DOWNLOAD_DATA_FILES set to
    # $Download. A stand-in for the data repository's script records each
    # download asked for.
    function Invoke-DataFileStep ([string[]]$Beside, [string]$Download) {
        $step = Get-DataFileStep
        $root = New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid()))
        $context = New-Item -ItemType Directory -Path "$root/context"
        New-Item -ItemType Directory -Path "$root/app/cxx/data/device-detection",
            "$root/app/cxx/data/ip-intelligence" | Out-Null
        Set-Content "$root/app/cxx/data/get-data-files.sh" "echo `"`$*`" >> '$root/downloads'"
        foreach ($name in $Beside) { Set-Content "$context/$name" $name }
        $script = "_51DEGREES_DOWNLOAD_DATA_FILES='$Download'`n" +
            ($step.Script -replace [regex]::Escape($step.Mount), $context)
        Push-Location "$root/app"
        try {
            $output = sh -c $script 2>&1
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $downloads = @(if (Test-Path "$root/downloads") { Get-Content "$root/downloads" })
        @{ Exit = $exit; Output = "$output"; Downloads = $downloads; Data = "$root/app/cxx/data" }
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

    It 'puts in place each data file the Docker example loads' {
        $loaded = Get-Names (Get-Text 'examples/curl/default.vcl')
        $loaded.Count | Should -Be 2
        Get-Names (Get-DataFileStep).Script | Should -Be $loaded
    }

    It 'downloads the Docker example''s data files by default' {
        Get-DownloadDefault | Should -Be 'true'
        $run = Invoke-DataFileStep -Beside @() -Download (Get-DownloadDefault)
        $run.Exit | Should -Be 0 -Because $run.Output
        $run.Downloads | Should -Be @(
            '-s examples-51degrees-varnish 51Degrees-LiteV4.1.hash'
            '-s examples-51degrees-varnish 51Degrees-IPIV4AsnIpiV41.ipi')
    }

    It 'uses a data file beside the Dockerfile in place of a download, with downloads <Download>' -ForEach @(
        @{ Download = 'true' }, @{ Download = 'false' }
    ) {
        $names = Get-Names (Get-Text 'examples/curl/default.vcl')
        $run = Invoke-DataFileStep -Beside $names -Download $Download
        $run.Exit | Should -Be 0 -Because $run.Output
        $run.Downloads | Should -BeNullOrEmpty
        "$($run.Data)/device-detection/51Degrees-LiteV4.1.hash" | Should -Exist
        "$($run.Data)/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi" | Should -Exist
    }

    It 'fails naming the missing data file, rather than download it, with downloads false' {
        $run = Invoke-DataFileStep -Beside @('51Degrees-LiteV4.1.hash') -Download 'false'
        $run.Exit | Should -Not -Be 0
        $run.Output | Should -Match '51Degrees-IPIV4AsnIpiV41\.ipi is not beside the Dockerfile'
        $run.Downloads | Should -BeNullOrEmpty
    }

    It 'builds the Docker example in CI from the data files fetch-assets gives it' {
        $text = Get-Text '.github/workflows/docker-example.yml'
        $fetch = [regex]::Match($text,
            '(?ms)uses: 51Degrees/common-ci/actions/fetch-assets@\S+\s+with:\s+assets: \|\s*\n(.*?)\n\s*cache: true')
        $fetch.Success | Should -BeTrue -Because 'the job fetches the data files through fetch-assets with its cache'
        $loaded = Get-Names (Get-Text 'examples/curl/default.vcl')
        Get-Names $fetch.Groups[1].Value | Should -Be $loaded
        $copy = $text -split '\r?\n' | Where-Object { $_ -match '^\s*run: cp ' }
        Get-Names "$copy" | Should -Be $loaded
        $copy | Should -Match ' examples/curl/$'
        $build = $text -split '\r?\n' | Where-Object { $_ -match '^\s*run: docker build ' }
        @($build).Count | Should -Be 1
        $build | Should -Match ' --build-arg _51DEGREES_DOWNLOAD_DATA_FILES=false '
    }

    It 'leaves the Docker example job no other way to a data file' {
        $text = Get-Text '.github/workflows/docker-example.yml'
        $text | Should -Not -Match 'actions/cache/restore@'
        $text | Should -Not -Match 'get-data-files'
        # The job sends requests only to the example it starts.
        $hosts = @([regex]::Matches($text, 'https?://([^\s"''/]+)') |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $hosts | Should -Be @('127.0.0.1:8080')
    }

    It 'downloads in the Docker example only in the data file step' {
        $text = Get-Text 'examples/curl/Dockerfile'
        [regex]::Matches($text, 'get-data-files').Count | Should -Be 1
        (Get-DataFileStep).Script | Should -Match 'get-data-files'
    }
}
