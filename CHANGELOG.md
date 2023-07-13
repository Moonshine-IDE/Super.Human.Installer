# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) 

## Super Human Installer [0.8.17]

This release upgrade [demo-tasks](https://github.com/DominoVagrant/demo-tasks) provisioner to version [0.1.20](https://github.com/DominoVagrant/demo-tasks/releases/tag/demo-tasks%2Fv0.1.20)

### Added

* Add MD5 hashes for newest version of installer Nomad-Web and Traveler ([#77](https://github.com/Moonshine-IDE/Super.Human.Installer/issues/77)

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
