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
$ nest uninstall swiftlint 0.55.0 # A verision can be specified.
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

## Configuration file.
`nest` supports to install multiple packages at once with a configuration file, 
and the file needs to be written in YAML.

`generate-nestfile` command generates the basic configuration file in the current directory.
```sh
$ nest generate-nestfile
```
And update the file based on your requirements.

```yaml
targets:
  # Example 1: Specify a repository
  - reference: mtj0928/nest # or htpps://github.com/mtj0928/nest
    version: 0.1.0 # When a version is not specified, the latest release will be used.
  # Example 2 Specify zip URL directly
  - https://github.com/mtj0928/nest/releases/download/0.1.0/nest-macos.artifactbundle.zip
```

Finally run `bootstrap` command. The command installs all bundles in the configuration file at once.
```sh
$ nest bootstrap nestfile.yaml
```
## Cache directory
`nest` stores artifacts at `~/.nest` as a default. 
If you want change the directory,
please update `$NEST_PATH` or specify `nestPath` in a configuration file (only `bootstrap`).

## Why is the name `nest`?
A nest is place where Swift birds store their crafts.
