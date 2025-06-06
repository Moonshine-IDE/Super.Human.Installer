---
title: CHANGELOG
layout: default
---

# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) 

## Super Human Installer [1.4.0]

The 1.4.0 release of Super.Human.Installer adds support for custom provisioners, fixes critical bugs, and improves overall stability and functionality.

### Added
* Added action to generate additional Domino server ID ([#124](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/124))
* Added support for custom provisioners ([#143](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/143))
* Added ability to cancel provisioning process ([#149](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/149))
* Added file cache and HCL Download Portal integration ([#155](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/155))
* Added global reusable secrets page for better security management ([#154](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/154))
* Added ability to view/edit Hosts.yml and Provisioner files before 'vagrant up' is issued ([#130](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/130))
* Added display of server path to Hosts.yml and Provisioners scripts during server creation ([#102](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/102))
* Added VirtualBox information display on the Servers page ([#30](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/30))

### Changed
* Updated Haxe to version 4.3.7 for improved performance and compatibility ([#152](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/152))
* Updated hxcpp to version 4.3.88 to fix local build issues on Mac ([#152](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/152))
* Improved documentation for using the application and development ([#156](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/156))
* Enhanced provisioner customization options with better documentation ([#84](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/84))
* Expanded support for additional provisioners ([#83](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/83))

### Fixed
* Fixed long path issue during Haxe/OpenFL build on GitHub Actions for Windows ([#129](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/129))
* Fixed bug where stopped server is deleted without deleting Vagrant instance ([#131](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/131))
* Fixed issue where rsync is not found on Windows despite being included in Vagrant's embedded binaries ([#137](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/137))
* Fixed issue where deleted servers were still flagged as provisioned ([#106](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/106))
* Fixed Windows build process and testing procedures ([#16](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/16))

## Super Human Installer [1.3.0]

The 1.3.0 release of Super.Human.Installer fixes critical bugs related to application stability and server configuration.

### Fixed
* Fixed issue where application crashes when file chooser dialog is opened twice ([#138](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/138))
* Fixed error where domino_rest_api fails even when not configured in server setup ([#144](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/144))

## Super Human Installer [1.2.0]

The 1.2.0 release of Super.Human.Installer adds support for additional Domino server configuration, improves server management, and updates installer components.

### Added
* Added Hotfix option for Nomad role ([#139](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/139))
* Added new hashes for latest versions ([#139](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/139)):
  * Nomad Web 1.0.15-IF1
  * Leap 1.0.17
  * Domino 12.0.2 FP6
* Added default enabled JEDI role for improved server functionality ([#141](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/141))

### Changed
* Phase 3 updates for [hcl_domino_standalone_provisioner v0.1.23](https://github.com/STARTcloud/hcl_domino_standalone_provisioner) ([#139](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/139))
* Phase 3 updates for [additional Domino servers](https://github.com/STARTcloud/hcl_domino_additional_provisioner) ([#139](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/139))
* Improved logging for gathering status of server ([#139](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/139))

### Fixed
* Fixed error when recreating server after deletion ([#92](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/92))
* Fixed isse where deleted server was still flagged as provisioned [#106](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/106))

## Super Human Installer [1.1.0]

The 1.1.0 release of Super.Human.Installer enhances Domino Server support and improves VM management capabilities.

### Added
* Added support for [additional Domino servers](https://github.com/STARTcloud/hcl_domino_additional_provisioner) ([#85](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/85))
* Phase 2 updates for [hcl_domino_standalone_provisioner v0.1.23](https://github.com/STARTcloud/hcl_domino_standalone_provisioner) ([#132](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/132))
* Added application sleep mode functionality ([#122](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/122))
* Read IP Address from results.yml for provisioner v0.1.23 ([#120](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/120))

### Fixed
* VM Destroy Button missing after stopping VM ([#104](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/104))

## Super Human Installer [1.0.0]

The 1.0.0 release of Super.Human.Installer brings support for HCL Domino 14 and includes important fixes for Vagrant 2.4.3 compatibility.

### Added
* Support for HCL Domino 14 installation and configuration ([#133](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/133))

### Fixed
* Compatibility fixes for Vagrant 2.4.3 ([#126](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/126))

## Super Human Installer [0.11.0]

The 0.11.0 release of Super.Human.Installer updates Domino provisioner to version [0.1.23](https://github.com/STARTcloud/hcl_domino_standalone_provisioner).

### Added
* Added option in Settings to switch between SCP and Rsync file synchronization methods [#118](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/118#issuecomment-2605447368)

### Changed
* Update Domino provisioner to version 0.1.23 ([#118](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/118))
* Update Ubuntu box version to [0.0.9](https://portal.cloud.hashicorp.com/vagrant/discover/STARTcloud/debian12-server) for provisioner 0.1.22 ([#125](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/125))

## Super Human Installer [0.10.0]

The 0.10.0 release of Super.Human.Installer update Domino provisioner to version [0.1.22](https://github.com/DominoVagrant/demo-tasks/compare/demo-tasks/v0.1.21...demo-tasks/v0.1.22). 

### Added
* Update Domino provisioner to version 0.1.22 ([#99](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/99))
* Add SCP application button for easier access to the VM contents ([#113](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/113))

### Known Issues
* Domino Provisioner: Issues have been reported with Domino Provisioner version 0.1.22 on Windows machines. It is recommended to use provisioner version 0.1.20 on Windows to avoid these issues. The provisioner functions correctly on macOS.

## Super Human Installer [0.9.0]

This release contains small updates in existing Domino provisioner 0.1.20. 

### Changed

* Temporary Update for Domino provisioner 0.1.20 ([#110](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/110))

## Super Human Installer [0.8.21]

This release reintroduce usage of Domino 12.0.1. It contains some small UI bug fixes.

### Changed

* Reintroduce Domino 12.0.1 ([#103](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/103))

### Fixed

* Server > Advanced > Network Interface Should Look Like Dropdown ([#94](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/94))
* Add dropdown arrow in Settings of server -> Advance -> Network Interface ([#96](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/96))

## Super Human Installer [0.8.20]

The release update source code of application to use newest Haxe 4.3.1. It contains some small bug fixes.

### Changed

* Update source code to Haxe 4.3.1 ([#91](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/91))

### Fixed

* Fixed issue where open folder on server page doesn't work ([#94](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/94))
* Fixed crash when deleting VM ([#78](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/78))

## Super Human Installer [0.8.19]

This release add service type interface which allows create different type of servers.

### Added

* Added service type interface when creating a new server. ([#88](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/88))
  
## Super Human Installer [0.8.18]

This release add ability to select default web browser used for open "Welcome" page currently running server. All links in application are going to be open with selected browser as well.

### Added

* Added selection of default browser ([#81](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/81))

### Fixed

* Fixed issue where user was unable to remove non configured server ([#74](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/74))
  
## Super Human Installer [0.8.17]

This release upgrade [demo-tasks](https://github.com/DominoVagrant/demo-tasks) provisioner to version [0.1.20](https://github.com/DominoVagrant/demo-tasks/releases/tag/demo-tasks%2Fv0.1.20)

### Added

* Add MD5 hashes for newest version of installer Nomad-Web and Traveler ([#77](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/77))

### Changed

* Update demo-tasks to version 0.1.20

## Super Human Installer [0.8.16]

This release improves installation of selected installers different than default.

### Added

* Allow user pick up different version of installers than provided as default one ([#76](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/76))
  
### Fixed

* Fixed crash when using nomad-server greater than 1.0.6 ([#75](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/75))

## Super Human Installer [0.8.15]

This release is primarily for including the Super.Human.Portal application, which will be used to view documentation and manage Genesis addins.

### Added

* Automatically install superhumanportal through Genesis on new servers ([#68](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/68))

### Fixed

* Windows: Fixed crash on application startup when VirtualBox or Vagrant is not installed ([#69](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/69))
