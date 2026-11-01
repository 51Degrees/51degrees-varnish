# API Specific CI Approach

For the general CI Approach, see [common-ci](https://github.com/51degrees/common-ci).

The following secrets are required:

* `ACCESS_TOKEN` - GitHub [access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) for cloning repositories, creating pull requests and tagging.
* `DEVICE_DETECTION_KEY` - licence key used to download the TAC data file for the tests.

## Differences

- There are no packages for a package manager, so the output of a publish is a new tag and a release, with a source tarball attached.
- Windows is not supported, as Varnish does not run there.
- The performance configurations in `options.json` have stable names with no Ubuntu or Varnish version, `ubuntu_DD` for device detection and `ubuntu_IPI` for IP Intelligence, so that each graph keeps its history.
- There is no package update step, as there are no package dependencies.
- The Varnish 6.0 builds need `libpcre3-dev`, which later Ubuntu releases may drop, so `options.json` names `ubuntu-24.04` rather than `ubuntu-latest`.
- `setup-environment.ps1` builds Varnish from the source its publisher gives, and fails if the file's SHA256 is not the one published with it. A version added to `options.json` needs its address and SHA256 added there too.

## Build Options

The additional build options for this repository are:

| Option | Type | Default | Purpose |
| ------ | ---- | ------- | ------- |
| `VarnishVersion` | string | `6.0.18` | The version of Varnish to build from source and test against. |
| `VinylVersion` | string | none | If set, the version of Vinyl Cache to build from source and test against, in place of Varnish Cache. |
| `MemCheck` | bool | `false` | If true, the unit tests run through `make mem-check`, with the modules built with the address sanitizer. |
