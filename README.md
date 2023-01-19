<!-- omit in toc -->
# Super.Human.Installer

- [Building the app](#building-the-app)
  - [Prerequisites](#prerequisites)
  - [Building on macOS (x86-64)](#building-on-macos-x86-64)
  - [Building on macOS (ARM64/AArch64)](#building-on-macos-arm64aarch64)
  - [Building on Windows](#building-on-windows)
  - [Building on Linux](#building-on-linux)
  - [Building for Neko VM](#building-for-neko-vm)
  - [Optional build parameters](#optional-build-parameters)
    - [-debug](#-debug)
    - [-Dlogcolor](#-dlogcolor)
    - [-Dlogmr](#-dlogmr)
    - [-Dlogverbose](#-dlogverbose)
    - [-Dpackageid={your-package-id}](#-dpackageidyour-package-id)
    - [-final](#-final)
- [Launching the app](#launching-the-app)
  - [Command line parameters](#command-line-parameters)

## Building the app

### Prerequisites

Successfully building the app requires the followings to be installed:

- [Haxe 4.2.5](https://haxe.org/download/)
- Neko VM 2.3.0 (for Neko builds) - Haxe installer will install Neko VM as well

Required and properly pre-configured Haxelibs:

- [HXCPP](https://lib.haxe.org/p/hxcpp/) - for Native/C++ builds
- Lime 8.0.0
- [OpenFL 9.2.0](https://www.openfl.org/download/) - Installing and setting up OpenFL 9.2.0 will install Lime 8.0.0 as well
- [FeathersUI 1.0](https://feathersui.com/learn/haxe-openfl/installation/)
- Actuate 1.9.0 - Will be installed with FeathersUI 1.0

C++ Compilers

- In order to successfully compile the app for native targets, a C++ compiler is required to be installed and configured. Please read the [relevant part of the Haxe manual](https://haxe.org/manual/target-cpp-getting-started.html) regarding the recommmended and supported C++ compilers.

Additional software required to run the app

- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)

### Building on macOS (x86-64)

To build the app for macOS (x86-64 native/C++), make sure you're in the root directory of the project and enter the followings in command line:

`openfl build mac`

or for debug builds

`openfl build mac -debug`

### Building on macOS (ARM64/AArch64)

> Note: Building the app on **arm64** architecture (namely Apple M1/M2 (Silicon) SOCs) is currently not possible. Neither HXCPP nor Lime works currently on arm64 natively. The x86-64 compilers and the toolchain, however, can be installed and configured if Rosetta is already installed, so the app can be built and launched if Rosetta is present.

### Building on Windows

To build the app for Windows (native/C++), make sure you're in the root directory of the project and enter the followings in command line:

`openfl build windows`

or for debug builds

`openfl build windows -debug`

### Building on Linux

To build the app for Linux (native/C++), make sure you're in the root directory of the project and enter the followings in command line:

`openfl build linux`

or for debug builds

`openfl build linux -debug`

### Building for Neko VM

> Neko build target is recommended for a quick local build, test, and deployment. The functionality and feature-set of the Neko build is equivalent of the Native/C++ build's.

To build the app for Neko, make sure you're in the root directory of the project and enter the followings in command line:

`openfl build neko`

or for debug builds

`openfl build neko -debug`

The generated app will be bundled with the necessary libraries and executables on all supported platforms.

For quick build-and-run enter `openfl test neko` or `openfl test neko -debug` in the command line.

### Optional build parameters

#### -debug

Builds the app with debug info. Enables `debug` and `verbose` [log levels](#command-line-parameters).

#### -Dlogcolor

Forces colorized console output.

#### -Dlogmr

Forces machine-readable logging. Please [read below](#command-line-parameters) for details

#### -Dlogverbose

Forces `verbose` log level, works only if `-debug` is also defined.

> **Important! Enabling verbose logging is strictly for development purposes. Enabling it may lead to potential memory leaks, app misbehaviors, errors, crashes, and may expose some (although not necessarily overly sensitive) user data. Please make sure it's not defined in public builds! Please [read below](#command-line-parameters) for more information**

#### -Dpackageid={your-package-id}

The app is being built with `net.prominic.genesis.superhumaninstaller` package id by default. If you want to change that without modifying project.xml, define your custom package id in the command line, e.g.

`openfl build mac -Dpackageid=com.myorganization.superhuman`

#### -final

Builds the app with *final release* configuration (disables debug info, debug and verbose logging, machine-readable output). Works only if `-debug` is omitted. Final release configurations are intended to build the public version of the app.

## Launching the app

If the compilation succeeds, the production app bundle will be placed in `./Export/Production/{platform}/bin`, the debug (development) builds in `./Export/Development/{platform}/bin` directory. 

> macOS note: Building and running the app bundle the first time on an external volume, the OS shows a dialog in which the user has to grant access to Removable Volumes for the app, which permission is neccessary for accessing the bundled assets. If the access is denied, the app might run into errors. If you accidentally clicked "Don't allow", open macOS Settings, select "Security & Privacy", click "Privacy" tab, select "Files and Folders" in the list on the left, and grant access to SuperHumanInstaller in the list on the right (by making sure of "Removable Volumes" checkbox is selected).

### Command line parameters

The app can be launched with the following optional command line parameters:

- `--color` Enable internally styled (colorized) console output. Useful to visually distinguish different level of messages. Messages printed to stderr are never styled.
- `--loglevel={level}` Define default logging level. Available values (in hierarchical order from bottom to top):
  - `none` or `0` Disable logging.
  - `fatal` or `1` Only fatal error messages will be printed and logged.
  - `error` or `2` Error messages (and below) will be printed and logged.
  - `warning` or `3` Warnings (and below) will be printed and logged.
  - `info` or `4` Informational messages (and below) will be printed and logged. **This is the default value**.
  - `debug` or `5` Debug messages (and below) will be printed and logged. Debug messages contain additional useful information for debugging. Can only be set if the app is built with `-debug` compiler parameter, otherwise it defaults to `info`.
  - `verbose` or `6` Only available if the app is built with `-debug` compiler parameter, otherwise it defaults to `info`. *Warning: it WILL print a lot of messages, most of them are only meaningful to the developers who are working on the app! (E.g. it might forward internally spawned native processes' stdout/stderr to its own stdout/stderr) **It's highly discouraged to make this option available in public builds!*** Please [read more above](#-dlogverbose)
  - > Notes on logging: All messages will be printed to stdout and a text file in `{applicationStorageDirectory}/log.txt`, errors and fatal errors/exceptions will be printed to stderr as well. Currently the app (the main process) only exits if a fatal error/exception occurs.
- `--mr` Generate machine-readable output (JSON formatted data). Machine-readable output always contains the message, the time-stamp (the most precise system time available in seconds (Float)), the level of the message (as Int), and an optional source file path and line number if the app is compiled with `-debug`. Useful if a (parent) process is intended to catch and parse stdout/stderr. Each line should be parsed separately as JSON objects. Machine-readable output is never styled. 
  - Example of an informational machine-readable log entry in debug build: `{"time":1670321372.27593,"level":4,"message":"Initializing Super.Human.Installer v0.1.0...","source":"Genesis/Source/genesis/application/GenesisApplication.hx:118"}`
- `--notimestamp` Disable time-stamps in logs (has no effect on machine-readable output)
- `--prune` [Prune](https://developer.hashicorp.com/vagrant/docs/cli/global-status#prune) invalid Vagrant machines on app start

Example of a command line launch with parameters:

`SuperHumanInstaller.exe --loglevel=warning --mr`

