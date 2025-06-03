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
Run this command.
This script downloads the latest artifact bundle of this repository, and installs nest by using nest in the artifact bundle.
```sh
curl -s https://raw.githubusercontent.com/mtj0928/nest/main/Scripts/install.sh | bash
```

## How to Use

### Install packages
```sh
$ nest install realm/SwiftLint 
$ nest install realm/SwiftLint 0.55.0 # A version can be specified.
$ nest install https://github.com/realm/SwiftLint 0.55.0
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
    checksum: adcc2e3b4d48606cba7787153b0794f8a87e5289803466d63513f04c4d7661fb # (Optional) This is recommended to add it.
  # Example 2 Specify zip URL directly
  - zipURL: https://github.com/mtj0928/nest/releases/download/0.1.0/nest-macos.artifactbundle.zip
    checksum: adcc2e3b4d48606cba7787153b0794f8a87e5289803466d63513f04c4d7661fb # (Optional) This is recommended to add it.
registries:
  github:
    - host: my-github-enterprise.example.com
      tokenEnvironmentVariable: "MY_GHE_TOKEN"
```

Finally run `bootstrap` command. The command installs all artifact bundles in the nestfile at once.
```sh
$ nest bootstrap nestfile.yaml
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

## Use GitHub API token to fetch Artifact Bundles

Fetching releases sometimes fails due to API limit, so we recommended to pass a GitHub API token.

### Use `GH_TOKEN` environment variable

The simplest way is the passing `GH_TOKEN` or `GHE_TOKEN` environment variable. nest uses the token for GitHub.com or any other GitHub Enterprise servers.

### Use `registries` in nestfile

If you want to use a token for GitHub Enterprise, you can specify the names of environment variables in the `registries` section in the nestfile.

nest will automatically resolve the environment variables to fetch from each server.

```yaml
registries:
  github:
    - host: github.com
      tokenEnvironmentVariable: "MY_GH_TOKEN"
    - host: my-github-enterprise.example.com
      tokenEnvironmentVariable: "MY_GHE_TOKEN"
```

If the value is not set, uses `GH_TOKEN` instead if available.

## Why is the name `nest`?
A nest is place where Swift birds store their crafts🪺
