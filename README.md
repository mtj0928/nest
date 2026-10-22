# 🪺 nest

nest is a package manager to install an executable binary which is made with Swift.

```
$ nest install realm/SwiftLint 
📦 Found an artifact bundle, SwiftLintBinary-macos.artifactbundle.zip, for SwiftLint.
🌐 Downloading the artifact bundle of SwiftLint...
✅ Success to download the artifact bundle of SwiftLint.
🪺 Success to install swiftlint.

$ nest install XcodesOrg/xcodes
🪹 No artifact bundles in the repository.
🔄 Cloning xcodes...
🔨 Building xcodes for 1.4.1...
🪺 Success to install xcodes.
```

**nest doesn't reach 1.0.0 yet. It may break backward compatibility.**

## Concept
nest is highly inspired by [mint](https://github.com/yonaskolb/Mint) and [scipio](https://github.com/giginet/Scipio).

mint is a tool to install and run executable Swift packages. 
The tool is so amazing, but the tool requires to build packages at first.
The build time cannot be ignored on Cl environment where caches are not available like Xcode Cloud.

scipio is a tool to generate and reuse xcframeworks.
The tool drastically reduced the build time for the pre-build frameworks 
by fetching XCFrameworks from remote storage and reusing them.

nest adopts the concept of these tools and reuses an artifact bundle to reduce the build time.
If there is an artifact bundle in GitHub release, nest downloads the artifact bundles and installs the executable binaries in the bundles.
If not, nest clones and builds the package and installs the executable binaries.

## Installation
Building nest from source requires Swift 6.2 or later and Xcode 26 or later. The minimum supported macOS version remains macOS 13.

Run this command.
This script downloads the artifact bundle for the release, verifies its SHA-256 checksum before extracting or running it, and installs nest by using nest in the artifact bundle.
The release workflow embeds the release tag and checksum in the installer attached to each release.
```sh
curl -fsSL https://github.com/mtj0928/nest/releases/latest/download/install.sh | bash
```
The previous `raw.githubusercontent.com` installer URL still works. It prints a warning and runs the release installer.

## How to Use

### Install packages
```sh
$ nest install realm/SwiftLint
$ nest install realm/SwiftLint 0.55.0 # A version can be specified.
$ nest install https://github.com/realm/SwiftLint 0.55.0

# Verify the artifact bundle against a known checksum.
$ nest install realm/SwiftLint 0.55.0 --checksum adcc2e3b...

# Installing a direct artifact bundle URL requires either --checksum.
$ nest install https://example.com/foo.artifactbundle.zip --checksum abc123...
```

### Uninstall package
```sh
$ nest uninstall swiftlint # All versions of swiftlint are uninstalled.
$ nest uninstall swiftlint 0.55.0 # A version can be specified.
```

### Show all binaries
```sh
$ nest list
```

### Switch command version
If multiple versions for a command are ionstalled, you can switch the linked version.
```sh
$ nest switch swiftlint 0.55.0 // swiftlint 0.55.0 are selected.
```

## Configuration file
`nest` supports to install multiple packages at once with a configuration file which is called nestfile,
and the file needs to be written in YAML.

`generate-nestfile` command generates the basic nestfile in the current directory.
```sh
$ nest generate-nestfile
```
Then add references to targets.

```yaml
nestPath: ./.nest
targets:
  # Example 1: Specify a repository
  - reference: mtj0928/nest # or htpps://github.com/mtj0928/nest
    version: 0.1.0 # (Optional) When a version is not specified, the latest release will be used.
    assetName: nest-macos.artifactbundle.zip # (Optional) When a name is not specified, it will be resolved by GitHub API.
    checksum: adcc2e3b4d48606cba7787153b0794f8a87e5289803466d63513f04c4d7661fb # Recommended now and required with `--checksum-policy require`. Run `update-nestfile` to populate.
  # Example 2 Specify zip URL directly
  - zipURL: https://github.com/mtj0928/nest/releases/download/0.1.0/nest-macos.artifactbundle.zip
    checksum: adcc2e3b4d48606cba7787153b0794f8a87e5289803466d63513f04c4d7661fb # Recommended now and required with `--checksum-policy require`.
registries:
  github:
    - host: my-github-enterprise.example.com
      tokenEnvironmentVariable: "MY_GHE_TOKEN"
```

Run `update-nestfile` to populate the `checksum` fields, then run `bootstrap` to install all artifact bundles in the nestfile at once.
```sh
$ nest update-nestfile nestfile.yaml
$ nest bootstrap nestfile.yaml

# Opt in to the future strict behavior now.
$ nest bootstrap nestfile.yaml --checksum-policy require
$ NEST_REQUIRE_CHECKSUM=1 nest bootstrap nestfile.yaml

# Allow targets without checksums without a warning. Any checksum present is still verified.
$ nest bootstrap nestfile.yaml --checksum-policy skip
```

### Update nestfile
nest provides two utility commands, `update-nestfile` and `resolve-nestfile`.

`update-nestfile` command overwrites the nestfile by updating the version and filling in the checksum and the asset name. 

```sh
$ nest update-nestfile nestfile.yaml

# Ignore updates of `realm/SwiftLint `
$ nest update-nestfile nestfile.yaml --excludes realm/SwiftLint

# Ignore versions of 0.58.1 and 0.58.2 of `realm/SwiftLint `
$ nest update-nestfile nestfile.yaml --excludes realm/SwiftLint@0.58.1 realm/SwiftLint@0.58.2
```

`resolve-nestfile` is a similar command but it doesn't update the version when one is specified.

### Run Packages in nestfile
The `run` command executes a package in the nestfile. 

```sh
# Run a tool specified in nestfile
$ nest run realm/SwiftLint foo.swift

# Use --no-install flag to prevent automatic installation and specify a custom nestfile location
$ nest run --nestfile-path custom-nestfile.yaml --no-install realm/SwiftLint foo.swift
```

The command will:
1. Look for the specified repository in the nestfile
2. Check if the required version is already installed
3. If not installed and `--no-install` is not specified, automatically install the required version
4. Execute the package with any additional arguments passed through

> [!NOTE]
> The `run` command requires a fixed version which is specified in the nestfile. If a version is not specified, the `run` command will return an error rather than using the latest version.

## Cache directory
`nest` stores artifacts at `~/.nest` as a default. 
If you want change the directory,
please update `$NEST_PATH` or specify `nestPath` in a configuration file (only `bootstrap`).

To reuse downloaded artifact bundle ZIP files across multiple nest paths, pass `--enable-user-scope-cache` when installing:

```sh
$ nest install realm/SwiftLint --enable-user-scope-cache
$ nest bootstrap nestfile.yaml --enable-user-scope-cache
$ nest run --enable-user-scope-cache realm/SwiftLint foo.swift
```

When this option is enabled, nest stores the downloaded ZIP file as-is under `~/Library/Caches/nest/artifact-bundle-zips`. The cache mirrors a safe, bounded portion of the source URL for readability and adds a URL hash to the ZIP file name for uniqueness. If a matching ZIP is already cached there, nest reuses it for checksum validation and installation instead of downloading the ZIP again.

## Use GitHub API token to fetch Artifact Bundles

Fetching releases sometimes fails due to API limit, so we recommended to pass a GitHub API token.

### Use `GH_TOKEN` for GitHub.com
Set `GH_TOKEN` to authenticate requests for repositories hosted on `github.com`.

### Use `registries` in nestfile

GitHub Enterprise hosts must use HTTPS and must be explicitly associated with a token environment variable in the `registries` section.
nest sends the resolved token only to the associated host. `GHE_TOKEN` is not applied implicitly to arbitrary custom hosts, but it can be selected explicitly as shown below.

```yaml
registries:
  github:
    - host: github.com
      tokenEnvironmentVariable: "MY_GH_TOKEN"
    - host: my-github-enterprise.example.com
      tokenEnvironmentVariable: "GHE_TOKEN"
```

If the configured variable for `github.com` is unset, nest uses `GH_TOKEN` when available.
There is no fallback token for a custom host: if its configured variable is unset, the request is sent without Authorization.

When `nest run` launches an installed executable, it preserves ordinary environment variables but removes `GH_TOKEN` and every token environment variable named in `registries`. `GHE_TOKEN` is removed only when it is explicitly selected in `registries`.

## Why is the name `nest`?
A nest is place where Swift birds store their crafts🪺
