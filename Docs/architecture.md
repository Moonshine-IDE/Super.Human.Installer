---
layout: default
title: Architecture
nav_order: 3
has_children: false
---

# Super.Human.Installer Architecture

This page provides an overview of the application's architecture, key components, and how they interact.

## High-Level Architecture

Super.Human.Installer is built using the Haxe programming language with the OpenFL and Feathers UI frameworks, allowing it to run across multiple platforms while maintaining a consistent user experience. It leverages external tools like Vagrant and VirtualBox for VM management and Ansible (via provisioners) for software configuration.

```mermaid
graph TD
    UserInterface[User Interface (Feathers UI)] --> AppCore[Core Application (SuperHumanInstaller.hx)]
    AppCore --> Managers[Manager Classes]
    Managers --> ProvisionerSystem[Provisioner System]
    Managers --> ExternalTools[External Tool Integrations]
    ProvisionerSystem --> ServerConfig[Server Configuration Files]
    ExternalTools --> Vagrant[Vagrant CLI]
    ExternalTools --> VirtualBox[VirtualBox CLI (VBoxManage)]
    ExternalTools --> Git[Git CLI]
    Vagrant --> VirtualBox
    Vagrant --> Ansible[Ansible (via Provisioner Scripts)]
    VirtualBox --> VM[Virtual Machines]
    Ansible --> VM
    ServerConfig --> Vagrant
```

## Key Components

### Core Application (`SuperHumanInstaller.hx`)

The main application class bootstraps the environment, initializes UI components and managers, handles application lifecycle events, manages global configuration (`.shi-config`), and orchestrates interactions between different parts of the system. It extends `GenesisApplication` for base framework features like logging, theming, and updates.

### User Interface (Feathers UI)

Built with the Feathers UI framework, the interface is organized into a series of pages (`superhuman.components.*`), each handling specific functionality:

*   **ServerPage**: Main view for listing and managing servers.
*   **ServiceTypePage**: Selection of provisioner types for new servers.
*   **ConfigPage / AdditionalServerPage / DynamicConfigPage**: Interfaces for basic server configuration depending on the provisioner type.
*   **AdvancedConfigPage / DynamicAdvancedConfigPage**: Interfaces for advanced server settings (networking, resources).
*   **RolePage**: UI for selecting software roles defined by the provisioner.
*   **SettingsPage**: Hub for application-wide settings.
    *   **SecretsPage**: Manages Git API tokens.
    *   **HashManagerPage**: Manages cached installer files and their hashes (File Cache).
    *   **ProvisionerImportPage**: UI for importing custom provisioners.
*   **HelpPage**: Displays help information and links.
*   **Console**: Displays real-time output from Vagrant/Ansible processes.

### Manager Classes (`superhuman.managers.*`)

Manager classes handle core business logic and state management:

*   **ServerManager**: Creates, tracks, and manages `Server` instances and their lifecycles (start, stop, provision, destroy). Determines server status based on Vagrant/VirtualBox output.
*   **ProvisionerManager**: Discovers, loads, caches, and imports provisioners (Standalone, Additional, Custom). Parses provisioner metadata (`provisioner-collection.yml`, `provisioner.yml`).
*   **ConsoleBufferManager**: Manages buffering of console output for display in the UI.
*   *(Note: Role-specific logic is primarily handled within the `Server` classes and the `RolePage` UI, not a dedicated `RoleManager`.)*

### Provisioner System (`superhuman.server.provisioners.*`)

The provisioner system defines how virtual machines are configured and software is installed:

*   **AbstractProvisioner**: Base class defining common file operations and the interface for provisioners.
*   **StandaloneProvisioner**: Default implementation for standalone HCL Domino servers. Generates `Hosts.yml` configuration.
*   **AdditionalProvisioner**: Extends `StandaloneProvisioner` for adding Domino servers to an existing environment.
*   **CustomProvisioner**: Extends `StandaloneProvisioner` to handle user-imported provisioners, dynamically generating configuration based on the imported provisioner's metadata and templates.
*   **HostsFileGenerators**: Classes responsible for generating the final `Hosts.yml` content based on server data and provisioner type.

### External Tool Integration (`prominic.sys.applications.*`)

Wrapper classes provide an abstraction layer for interacting with command-line tools:

*   **VirtualBox**: Interfaces with `VBoxManage` to list VMs, get host info, manage VM state, etc. Parses CLI output.
*   **Vagrant**: Interfaces with the `vagrant` command for VM lifecycle management (up, halt, destroy, provision, status, rsync), SSH access, and state parsing.
*   **Git**: Interfaces with the `git` command, primarily used for cloning repositories during provisioner import.
*   **Shell / Executor**: Lower-level classes for executing arbitrary system commands and managing their processes, leveraging `cpp.NativeProcess`.

## Data Flow

1.  User interacts with UI components (e.g., clicks "Start Server").
2.  UI component dispatches an event (e.g., `SuperHumanApplicationEvent.START_SERVER`).
3.  `SuperHumanInstaller.hx` catches the event and calls the appropriate method on a Manager or Server instance (e.g., `server.start()`).
4.  The `Server` object interacts with its associated `Provisioner` to ensure configuration files (`Hosts.yml`) are up-to-date in the server's directory.
5.  The `Server` object uses the `Vagrant` integration class to execute the relevant Vagrant command (e.g., `vagrant up`).
6.  The `Vagrant` class uses the `Executor` system (based on `NativeProcess`) to run the command.
7.  Vagrant interacts with VirtualBox (via its CLI integration) to create/manage the VM.
8.  Vagrant runs provisioning scripts (Ansible) defined by the `Provisioner`.
9.  Output from Vagrant/Ansible is captured by the `Executor` and displayed in the `Console`.
10. `ServerManager` periodically refreshes VM status by calling `Vagrant` and `VirtualBox` integration methods.
11. UI components update based on server status changes and events.

## File Organization

The codebase is primarily organized into:

*   **`Source/superhuman/`**: Core application code specific to SHI.
    *   `application/`: External application integration (e.g., FileZilla).
    *   `browser/`: Browser integration.
    *   `components/`: UI pages and custom components.
    *   `config/`: Configuration data structures (`SuperHumanConfig`, `SuperHumanPreferences`, `SuperHumanSecrets`).
    *   `events/`: Custom application event definitions.
    *   `interfaces/`: Haxe interfaces (e.g., `IConsole`).
    *   `managers/`: Core logic managers (`ServerManager`, `ProvisionerManager`, `ConsoleBufferManager`).
    *   `server/`: Server-related classes, including data structures, provisioners, roles, and status definitions.
    *   `theme/`: UI theme definitions.
*   **`Genesis/Source/`**: Reusable framework code (likely from Prominic.NET's internal Genesis framework).
    *   `genesis/application/`: Base application structure, UI components, managers (Language, Toast).
    *   `prominic/sys/`: System-level utilities, including external application wrappers (`Vagrant`, `VirtualBox`, `Git`, `Shell`) and IO (`Executor`).
    *   `cpp/`: Native process bindings.

## Relevant Files

Key files for understanding the architecture:

*   `Source/SuperHumanInstaller.hx` - Main application class.
*   `Source/superhuman/managers/ServerManager.hx` - Server instance management.
*   `Source/superhuman/managers/ProvisionerManager.hx` - Provisioner discovery and management.
*   `Source/superhuman/server/Server.hx` - Core server object logic.
*   `Source/superhuman/server/provisioners/AbstractProvisioner.hx` - Base provisioner class.
*   `Genesis/Source/prominic/sys/io/Executor.hx` - Core command execution logic.
*   `Genesis/Source/prominic/sys/applications/hashicorp/Vagrant.hx` - Vagrant CLI wrapper.
*   `Genesis/Source/prominic/sys/applications/oracle/VirtualBox.hx` - VirtualBox CLI wrapper.
