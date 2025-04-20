---
layout: default
title: Home
nav_order: 1
---

# Super.Human.Installer Documentation

Welcome to the Super.Human.Installer documentation wiki. This wiki provides comprehensive information about using and understanding the Super.Human.Installer application.

## About Super.Human.Installer

Super.Human.Installer (SHI) is a cross-platform application built with Haxe, OpenFL, and Feathers UI. It allows you to easily create and manage virtual machines using Vagrant, VirtualBox, and Ansible. Initially designed for HCL Domino environments, SHI has evolved to support custom provisioners, enabling deployment and management of various server types.

SHI empowers developers, administrators, and testers to:

*   Create consistent development and testing environments across Windows, macOS, and Linux.
*   Deploy multiple server configurations with minimal effort using predefined or custom roles.
*   Manage complex virtual environments through an intuitive graphical interface.
*   Share provisioner configurations within teams or the community.

## Key Features

*   **Cross-platform support**: Runs natively on Windows, macOS, and Linux.
*   **Multiple provisioner types**: Supports built-in Standalone and Additional provisioners (primarily for HCL Domino) and allows importing Custom provisioners for diverse environments.
*   **Role-based configuration**: Easily enable or disable software components (roles) defined within a provisioner.
*   **File synchronization**: Synchronize files between the host machine and guest VMs using Rsync or SCP.
*   **Cached installers**: Manage and verify local copies of installation files (installers, fixpacks, hotfixes) using SHA256 hashes.
*   **Custom provisioners**: Import provisioners from local directories or GitHub repositories to extend functionality.
*   **Secrets Management**: Securely store Git API tokens for accessing private repositories.

## Documentation Contents

*   **[Getting Started](getting-started)** - Installation and initial setup.
*   **[Architecture](architecture)** - Overview of how SHI is structured.
*   **Using the Application**
    *   **[Server Management](vm-management)** - Creating and managing virtual machines.
    *   **[Creating & Configuring Servers](creating-and-configuring-servers)** - Detailed steps for server setup. (*New Page*)
    *   **[Settings & Management](settings-page)** - Application settings and management tools.
        *   **[Secrets Management](secrets-page)** - Managing API keys and credentials.
        *   **[File Cache & Hashes](file-cache)** - Managing installation files.
        *   **[Provisioner Import](provisioner-import)** - Importing custom provisioners.
*   **[Provisioner System](provisioner-system)** - Understanding the provisioner architecture.
    *   **[Creating Custom Provisioners](creating-custom-provisioners)** - Guide for developing your own provisioners. (*New Page*)
*   **[Help & Support](help-page)** - Links and how to report issues. (*New Page*)

## Additional Resources

*   [GitHub Repository](https://github.com/Prominic/Super.Human.Installer) - Access the source code.
*   [Issue Tracker](https://github.com/Prominic/Super.Human.Installer/issues) - Report bugs or request features.

## About This Documentation

This documentation is designed to help both new and experienced users get the most out of Super.Human.Installer. If you find any issues or have suggestions for improvement, please feel free to contribute or report issues in the GitHub repository.
