---
layout: default
title: Provisioner System
nav_order: 8 # Adjusted order to place it after main usage sections
has_children: true # This page has sub-pages
---

# Provisioner System

The provisioner system is the core mechanism in Super.Human.Installer (SHI) responsible for defining how virtual machines are configured and provisioned with software.

## What is a Provisioner?

A provisioner is a structured project defining a specific server environment. It includes:

*   **Metadata**: Name, type, description, version, author.
*   **Configuration Fields**: Defines basic and advanced settings exposed in the SHI UI.
*   **Roles**: Defines software components (like Domino, Traveler) that can be installed.
*   **Templates**: Base files (like `Hosts.template.yml`) used to generate VM configuration.
*   **Scripts/Playbooks**: Ansible playbooks, roles, and other scripts executed by Vagrant during provisioning.

SHI uses this information to present configuration options to the user and generate the necessary files (`Hosts.yml`) within a server instance's directory to instruct Vagrant and Ansible.

## Provisioner Types

SHI supports three main categories of provisioners:

1.  **Standalone Provisioner** (`hcl_domino_standalone_provisioner`): The default provisioner, primarily designed for setting up standalone HCL Domino servers. Implemented in `StandaloneProvisioner.hx`.
2.  **Additional Provisioner** (`hcl_domino_additional_provisioner`): Extends the standalone type, designed for adding Domino servers to an existing environment. Implemented in `AdditionalProvisioner.hx`.
3.  **Custom Provisioner**: User-defined provisioners imported into SHI. These can configure any type of software or environment supported by Vagrant and Ansible. Handled by `CustomProvisioner.hx`.

## Provisioner Structure and Metadata

Provisioners are stored within the application's storage directory under a `provisioners` subfolder. Each provisioner type has its own directory, containing versioned subdirectories.

```
<AppStorage>/provisioners/
└── hcl_domino_standalone_provisioner/  # Example: Provisioner Type Directory
    ├── provisioner-collection.yml      # REQUIRED: Defines the collection metadata (name, type, desc)
    ├── 0.1.23/                         # Example: Version Directory
    │   ├── provisioner.yml             # REQUIRED: Version-specific metadata (roles, config fields)
    │   ├── templates/                  # Directory for template files (e.g., Hosts.template.yml)
    │   ├── ansible/                    # Optional: Ansible playbooks/roles
    │   └── ...                         # Other files/directories needed by the provisioner
    └── 0.1.22/                         # Another version directory
        └── ...
```

**Key Metadata Files:**

*   **`provisioner-collection.yml`**: Located at the root of the provisioner type directory. Defines the overall collection.
    *   `name`: Display name (e.g., "HCL Domino Standalone Provisioner").
    *   `type`: Unique identifier string (e.g., "hcl_domino_standalone_provisioner").
    *   `description`: Brief description.
    *   `author`: (Optional) Author name.
*   **`provisioner.yml`**: Located within *each* version subdirectory. Defines version-specific details.
    *   `name`, `type`, `description`, `author`: Can override collection values if needed.
    *   `version`: The semantic version string (e.g., "0.1.23"). *Note: SHI primarily uses the directory name as the version identifier.*
    *   `roles`: (Optional) An array defining software roles (see below).
    *   `configuration`: (Optional) Defines UI fields.
        *   `basicFields`: Array of fields for the main config page.
        *   `advancedFields`: Array of fields for the advanced config page.

**Field Definition Structure (within `configuration`):**

```yaml
- name: "variableNameInTemplate" # Used in ::variableNameInTemplate::
  type: "text"                   # text, number, checkbox, dropdown
  label: "User-Friendly Label"
  defaultValue: "Default Value"  # Optional
  required: true                 # Optional (default: false)
  hidden: false                  # Optional (default: false) - Hides field from UI but still processed
  tooltip: "Help text for user"  # Optional
  placeholder: "Hint text in input" # Optional
  restrict: "a-zA-Z0-9-"        # Optional (for text type)
  options:                       # Optional (for dropdown type)
    - value: "option1"
      label: "Option 1 Display"
    - value: "option2"
      label: "Option 2 Display"
  min: 0                         # Optional (for number type)
  max: 100                       # Optional (for number type)
```

## Roles

Roles represent installable software components or configurations within a provisioner. They are defined in the `provisioner.yml` file.

**Role Definition Structure (within `roles` array):**

```yaml
- name: "domino"                 # Internal name used in configuration
  label: "Domino Server"         # Display name in UI (RolePage)
  description: "Installs HCL Domino"
  defaultEnabled: true           # Optional (default: false)
  required: false                # Optional (default: false) - If true, cannot be disabled by user
  installers:                    # Optional: Defines which file types are needed
    installer: true              # Requires main installer file
    fixpack: true                # Requires fixpack file
    hotfix: false                # Does not require hotfix file
```

The `RolePage` UI allows users to enable/disable these roles (unless `required: true`) and associate the necessary installer files managed by the [File Cache & Hashes](file-cache). The enabled status and file paths are stored per server instance.

## ProvisionerManager (`ProvisionerManager.hx`)

This class is central to the system:

*   **Discovery & Caching**: Scans the `provisioners` directory on startup, parses metadata, and caches available `ProvisionerDefinition` objects.
*   **Importing**: Handles importing new provisioners from local directories or GitHub via the `ProvisionerImportPage`.
*   **Metadata Access**: Provides functions to retrieve provisioner definitions and metadata needed by the UI and server configuration logic.

## Relevant Files

*   [Source/superhuman/managers/ProvisionerManager.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/managers/ProvisionerManager.hx) - Management of provisioners.
*   [Source/superhuman/server/provisioners/AbstractProvisioner.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/provisioners/AbstractProvisioner.hx) - Base class.
*   [Source/superhuman/server/provisioners/StandaloneProvisioner.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/provisioners/StandaloneProvisioner.hx) - Implementation for standalone type.
*   [Source/superhuman/server/provisioners/AdditionalProvisioner.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/provisioners/AdditionalProvisioner.hx) - Implementation for additional type.
*   [Source/superhuman/server/provisioners/CustomProvisioner.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/provisioners/CustomProvisioner.hx) - Implementation for custom types.
*   [Source/superhuman/server/provisioners/ProvisionerType.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/provisioners/ProvisionerType.hx) - Enum defining core types.
*   [Source/superhuman/server/definitions/ProvisionerDefinition.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/definitions/ProvisionerDefinition.hx) - Data structure for cached definitions.
*   [Source/superhuman/server/data/ProvisionerData.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/data/ProvisionerData.hx) - Data structure stored in server config.
*   [Source/superhuman/components/ProvisionerImportPage.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/components/ProvisionerImportPage.hx) - UI for importing.
*   [Source/superhuman/components/RolePage.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/components/RolePage.hx) - UI for configuring roles.
*   [Source/superhuman/server/hostsFileGenerator/](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/hostsFileGenerator/) - Classes generating `Hosts.yml`.
