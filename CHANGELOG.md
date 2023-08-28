# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) 

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
