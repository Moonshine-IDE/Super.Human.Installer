# Hosts Configuration Templates

This repository contains two main configuration templates for provisioning virtual machines: `debug-Hosts.yml` and `SHI-Hosts.yml`. These templates are used to define the settings and configurations for different environments.

## Templates Overview

### debug-Hosts.yml

- **Purpose**: This is a non-templated version used by a developer across various builds. It is designed to work on both Bhyve and VirtualBox simultaneously.
- **Usage**: This file is used directly without any templating. It contains all the necessary configurations for a specifc development environment, a good resource for how to structure yours.

### SHI-Hosts.yml

- **Purpose**: This is a templated version specifically for the Super.Human.Installer project.
- **Usage**: This file is processed with a templating engine to generate the final `Hosts.yml` file for use in the Super.Human.Installer project.

### Add your own here!

If you want to add your own, update this README.md with a brief description of what it does. In your Pull request be sure to mention why it should different from the debug or SHI versions.