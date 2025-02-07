# Role Name
=========

## Description
This role installs Haxe and sets up the necessary environment for developing applications with Haxe. It includes tasks for downloading the Haxe compiler, extracting it, and setting up Haxelib, the package manager for Haxe.

## Requirements
------------
- Ensure that the target system meets the prerequisites for running Haxe, such as having a compatible operating system and sufficient disk space.

## Role Variables
------------------

Variables can be set in the `defaults/main.yml` file or overridden in the inventory file or through extra vars. Some notable variables include:

- `haxe_version`: Specifies the version of Haxe to download and install.
- `service_user`: Defines the user under which Haxe and its libraries will be installed. Defaults to 'startcloud'.
- `additional_haxe_libraries`: A list of additional Haxe libraries to install after setting up Haxelib.

## Dependencies
------------

This role depends on the following:

- Other roles hosted on Galaxy can be included as dependencies by specifying them in the `meta/main.yml` file.

## Example Playbook
-------------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

```
yaml

hosts: servers roles:
{ role: username.haxe_install, haxe_version: 4.3.4, additional_haxe_libraries: ['neko', 'lime'] }
```

## License
-------

BSD

## Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).