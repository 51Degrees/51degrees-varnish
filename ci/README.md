# API Specific CI Approach

For the general CI Approach, see [common-ci](https://github.com/51degrees/common-ci).

The following secrets are required:

* `ACCESS_TOKEN` - GitHub [access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) for cloning repositories, creating pull requests and tagging.
* `DEVICE_DETECTION_KEY` - licence key used to download the TAC data file for the tests.

## Differences

- There are no packages for a package manager, so the output of a publish is a new tag and a release, with a source tarball attached.
- Windows is not supported, as Varnish does not run there.
- The performance configurations in `options.json` have stable names with no Ubuntu or Varnish version, `ubuntu_DD` for device detection and `ubuntu_IPI` for IP Intelligence, so that each graph keeps its history.
- `select-options.ps1` leaves those two out of a pull request, as they build and test what the Varnish 9.1.0 entry does. They run when `rc` itself or the release pull request is built, which `.github/workflows/release-pull-request.yml` does on every entry.
- There is no package update step, as there are no package dependencies.
- The Varnish 6.0 builds need `libpcre3-dev`, which later Ubuntu releases may drop, so `options.json` names `ubuntu-24.04` rather than `ubuntu-latest`.
- `setup-environment.ps1` builds Varnish from the source its publisher gives, and fails if the file's SHA256 is not the one published with it. A version added to `options.json` needs its address and SHA256 added there too.
- `fetch-assets.ps1` takes every data file the tests read from common-ci's assets, which each run fetches once and caches because the workflows set `cache-assets`, so no test job downloads a data file. It copies the Lite Hash data file into `cxx/data/device-detection`, and the ASN and Lite IP Intelligence data files into `cxx/data/ip-intelligence`, where the data submodule holds only a link to each. `run-unit-tests.ps1` then runs `make check` with nothing set, as in a fresh clone, so the unit tests read the Lite Hash file from there, the IP Intelligence module tests and the `ubuntu_IPI` performance run the ASN file, and the IP Intelligence and mixed example tests the Lite IP Intelligence file. A data file a test starts to use needs an entry in common-ci's `steps/fetch-assets.ps1` first.

## Build Options

The additional build options for this repository are:

| Option | Type | Default | Purpose |
| ------ | ---- | ------- | ------- |
| `VarnishVersion` | string | `6.0.18` | The version of Varnish to build from source and test against. |
| `VinylVersion` | string | none | If set, the version of Vinyl Cache to build from source and test against, in place of Varnish Cache. |
| `MemCheck` | bool | `false` | If true, the unit tests run through `make mem-check`, with the modules built with the address sanitizer. |
