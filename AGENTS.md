# Working in this repository

If you have been asked to get an example running, follow
[Run the examples](#run-the-examples). It gives every step in order, from a
fresh clone to a response from Varnish. The sections after it are notes on
what is not obvious from the code, for changing it. Keep them short and
current. The [README](README.md) describes the VCL functions, the build
options and the tests.

## Run the examples

The examples are VCL files in `examples`. There are two modules,
`fiftyonedegrees` for Device Detection and `fiftyonedegrees_ipi` for IP
Intelligence. You build both, run every example through Varnish's own test
program with `make check`, then start Varnish with the curl example's VCL,
which uses both modules, and send it a request with `curl`. Run each command
from the repository root unless the step says otherwise. There are no cloud
examples, because the modules work only on-premise, with a data file.

### Prerequisites

- Linux. CI builds and tests on Ubuntu 24.04 only. `ci/README.md` says Windows
  is not supported, as Varnish does not run there, and CI does not build on
  macOS. On Windows or macOS, use the Docker image at the end of "Run".
- The packages the README names, gcc, autoconf, automake, the Varnish
  development files and Varnish itself.
- `libtool` and `pkg-config`, which `autogen.sh` runs, and Python 3, which
  `configure` needs. CI installs `libtool` and `pkg-config` in
  `ci/setup-environment.ps1`.
- `curl`, `gzip` and `md5sum`, which the data repository's download script
  needs, and network access to `distributor.51degrees.com` for the data
  files. `curl` also sends the request in "Run".
- Git.

On Ubuntu, the README installs its packages with this command.

```
sudo apt-get install gcc autoconf automake libvarnishapi-dev varnish
```

Clone the repository with its submodules.

```
git clone --recursive https://github.com/51Degrees/51degrees-varnish.git
cd 51degrees-varnish
```

In a clone made without `--recursive`, fetch the submodules.

```
git submodule update --init --recursive
```

### Data files

The examples and tests use free data files, which need no licence key. They
are not stored in this repository. The `cxx` submodule holds the
[data](https://github.com/51Degrees/data) repository as `cxx/data`, which has a
link to each file, and a script downloads them into `cxx/data/device-detection`
and `cxx/data/ip-intelligence`, where the default data file paths in
`configure.ac` (`datafile=` and `datafileipi=`) point. Nothing in the build
downloads a file, so download the Device Detection Lite file and the IP
Intelligence ASN file first.

```
sh cxx/data/get-data-files.sh 51Degrees-LiteV4.1.hash 51Degrees-IPIV4AsnIpiV41.ipi
```

The script keeps a file that is already there.

#### Check the files

- `cxx/data/device-detection/51Degrees-LiteV4.1.hash` is more than 10 MB.
- `cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi` is more than 1 MB.

### Build

These are the commands `ci/build-project.ps1` runs.

```
./autogen.sh
./configure --with-config=test
make
```

`--with-config=test` adds the functions the tests use, and `make check` needs
them. The README recommends the default, `release`, for production. The
modules are built into `src/dd/.libs` and `src/ipi/.libs`. Nothing here needs
`sudo make install`.

### Run

Run the tests of both modules and of the examples through `varnishtest`, with
the free data files, as CI's unit test job does.

```
make check
```

Then start Varnish in the background with the VCL from the curl example,
which sets each value on a response header and needs no backend. The `sed`
command points the VCL at the data files in your checkout, as
`tests/examples/curl.vtc` does, and `varnishd` loads the modules from the
build folders, as `ci/run-integration-tests.ps1` does.

```
sed "s#/app/cxx/#$PWD/cxx/#" examples/curl/default.vcl > /tmp/51d-default.vcl
varnishd -n /tmp/51d-varnish -P /tmp/51d-varnish.pid -a 127.0.0.1:8080 -f /tmp/51d-default.vcl -p vmod_path=$PWD/src/dd/.libs:$PWD/src/ipi/.libs
```

Send the request that `examples/curl/README.md` gives.

```
curl --head -H 'X-Real-IP: 212.58.224.22' \
     -H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53' \
     http://127.0.0.1:8080/
```

Stop Varnish.

```
kill $(cat /tmp/51d-varnish.pid)
```

On Windows or macOS, the curl example builds Varnish and both modules in an
Ubuntu image, with these commands from `examples/curl/README.md`.

```
cd examples/curl
docker build -t 51d-varnish-curl .
docker run -d -p 8080:8080 51d-varnish-curl
```

Then send the same request. The image clones `main` from GitHub rather than
using your checkout, and builds Varnish Cache 9.1.0, one of the versions CI
tests, from its GitHub release after checking its SHA256.

### Correct output

`make check` prints a line for each test, such as
`#    top  TEST ./tests/examples/gettingStarted.vtc passed (0.512)`, with its
own time. The getting-started examples are `gettingStarted.vtc` for Device
Detection, `ipiGettingStarted.vtc` for IP Intelligence and
`mixedGettingStarted.vtc` for both. `liteDataFile.vtc` checks what the examples
say about the Enterprise data file on the Lite file, and `enterpriseDataFile.vtc`
that they say nothing on a paid file. Each runs only when the tests are given
the file it needs, and is skipped otherwise. Each test passes or is skipped, and
`make` exits with 0.

The request answers with `200 OK` and the values in the response headers,
such as `x-is-mobile: True` and `x-asn: \"BBC\":1`, as
`examples/curl/README.md` says. A run of the Docker image on Varnish Cache
9.1.0, in
[run 43502369747](https://github.com/51Degrees/51degrees-varnish/actions/runs/43502369747),
gave these headers.

```
HTTP/1.1 200 OK
Server: Varnish
x-device-type: N/A
x-platform-name: iOS
x-platform-version: 7.1
x-browser-name: Mobile Safari
x-browser-version: 7.0
x-is-mobile: True
x-asn: \"BBC\":1
```

A property the data file does not have reads `N/A`, as `x-device-type` does
here, because the Lite file has no DeviceType. IP Intelligence values take the
form `"value":weight`, with each double quote escaped by a backslash.

The examples ask for some properties only the Enterprise data file has, such as
HardwareVendor, HardwareName and DeviceType, or Country, Latitude and Longitude.
When they read `N/A`, an `x-enterprise` header, or a note on the example's page,
says where to ask for a copy of the Enterprise data file, so the Docker image
built from these changes also sends `x-enterprise`.

The Enterprise data files have many more properties.
[Contact us](https://51degrees.com/contact-us?utm_source=github&utm_medium=docs&utm_campaign=51degrees-varnish&utm_content=agents.md&utm_term=correct-output)
for a copy.

### Cloud examples

There are none. The Varnish modules work only on-premise, with a data file.

### Pitfalls

- **A data file that is not there.** `cxx/data` holds a `.link` for each file
  rather than the file. `configure` does not check the data files, so it
  passes, but the tests fail. When the Device Detection module cannot load
  its data file it calls `abort()` (`loadFileErrorAbort` in
  `src/dd/vmod_fiftyonedegrees.c`), so the Varnish child process stops and
  requests get no answer. The IP Intelligence module refuses the VCL instead,
  as the README says. Download the files and check their sizes as above.
- **Missing submodules.** `configure` then stops with "source file not found,
  this is likely because the git submodule has not ben pulled."
- **Windows line endings.** The repository has no `.gitattributes`, so a
  checkout made by Git for Windows, which usually sets `core.autocrlf=true`,
  gives `autogen.sh` and the other scripts Windows line endings, and the shell
  cannot run them. Clone on Linux or inside WSL.
- **The README's `varnishd ... -d`.** The `-d` option starts Varnish in debug
  mode, which waits for `start` to be typed at its prompt, and the README's
  form also needs `sudo make install` and the data file path edited in the
  VCL. Use the `varnishd` command in "Run" instead.
- **The getting-started VCLs need a backend.** `examples/hash/gettingStarted.vcl`
  and the IP Intelligence and mixed ones pass each request to a backend at
  `127.0.0.1:80`, and load their data files from `/etc/varnish`. Their tests
  replace both, so outside the tests a request gets an error status from
  Varnish unless something answers on that port. The curl example's VCL
  answers by itself, which is why "Run" uses it.
- **The Varnish version.** CI builds Varnish from source in the versions
  `ci/options.json` lists, with `ci/setup-environment.ps1`, and does not use
  the distribution's packages. The packages the README names give the version
  your distribution carries.
- **Port 8080 in use.** `varnishd` then cannot listen. Pick another address
  with `-a`, and send the request there.
- **What CI does not test.** CI's tests use the Lite file that common-ci
  fetches, and the larger paid file, rather than a copy downloaded into
  `cxx/data` (`ci/run-unit-tests.ps1` and `ci/run-integration-tests.ps1`).
  `ci/fetch-assets.ps1` downloads the ASN file with the data repository's
  script, as the steps here do. CI does not build the Docker image.

## Building the modules

Each module is its own library, because IP Intelligence needs the common C
code compiled differently from Device Detection, as the README explains.
`configure` writes `src/dd/vmod_fiftyonedegrees.vcc` and
`src/dd/vmod_fiftyonedegrees_extra.h` from the `.template` files beside them,
adding the test functions for `--with-config=test`. Git ignores both outputs,
so change the templates. The module sources build with `-Werror`.

Each example has a test in `tests/examples` that rewrites the VCL's data
file paths and backend and runs it. `make check`
runs them all, so a change to an example needs its test to pass.

## CI

The workflows call the shared workflows in
[common-ci](https://github.com/51Degrees/common-ci), which run the scripts in
`ci/`. `ci/setup-environment.ps1` builds each Varnish or Vinyl Cache version
from source and checks its SHA256, so a version added to `ci/options.json`
needs its address and SHA256 added there too. The nightly submodule update
moves `cxx` with a pull request into `rc`.

## Versions

`ci/get-next-package-version.ps1` works out the version from the release tags
with GitVersion and common-ci's `GitVersion.yml`, so each release moves only
the patch number. Never move the major or minor number, and never add a
`+semver:` directive to a commit.
