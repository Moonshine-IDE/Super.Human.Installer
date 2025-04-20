---
layout: default
title: Creating Custom Provisioners
parent: Provisioner System
nav_order: 1 # First child of Provisioner System
has_children: false
---

# Creating Custom Provisioners

Super.Human.Installer (SHI) allows users to create and import custom provisioners, enabling the automated setup of diverse server environments beyond the built-in HCL Domino types. This guide outlines the structure and metadata required to build your own provisioner compatible with SHI.

## Prerequisites

*   Understanding of Vagrant and Vagrantfiles.
*   Understanding of a configuration management tool supported by Vagrant (Ansible is commonly used and expected by SHI's structure, but others like Shell scripts might work).
*   Familiarity with YAML syntax for metadata files.

## Provisioner Directory Structure

Your custom provisioner must follow a specific directory structure to be recognized by SHI. It consists of a main directory named after the provisioner `type`, containing a collection metadata file and versioned subdirectories.

```
<Your Provisioner Directory>/
└── my_custom_webserver/                # Directory named after your provisioner 'type'
    ├── provisioner-collection.yml      # REQUIRED: Defines the collection
    └── 1.0.0/                          # REQUIRED: Version subdirectory
        ├── provisioner.yml             # REQUIRED: Defines this version
        ├── templates/                  # REQUIRED: Contains template files
        │   └── Hosts.template.yml      # REQUIRED: Template for Ansible inventory/vars
        │   └── Vagrantfile.template    # Optional: Template for Vagrantfile (if needed)
        ├── ansible/                    # Optional: Ansible playbooks, roles, etc.
        │   └── playbook.yml
        ├── scripts/                    # Optional: Shell scripts or other files
        └── ...                         # Other necessary files/directories
```

## Metadata Files

### 1. `provisioner-collection.yml`

This file resides at the root of your provisioner type directory (e.g., `my_custom_webserver/`). It defines the overall provisioner collection.

**Required Fields:**

*   `name`: (String) User-friendly display name (e.g., "My Custom Web Server").
*   `type`: (String) A unique identifier string for this provisioner type (e.g., `my_custom_webserver`). Use lowercase letters, numbers, and underscores. **This MUST match the directory name.**
*   `description`: (String) A brief description shown in the Service Type selection UI.

**Optional Fields:**

*   `author`: (String) Your name or organization.

**Example `provisioner-collection.yml`:**

```yaml
name: "My Custom Web Server"
type: "my_custom_webserver"
description: "Provisions a standard LAMP stack."
author: "Your Name"
```

### 2. `provisioner.yml`

This file resides inside *each version subdirectory* (e.g., `my_custom_webserver/1.0.0/`). It defines the specifics for that version.

**Required Fields:**

*   `name`: (String) Display name (can be same as collection or more specific).
*   `type`: (String) Must match the `type` in `provisioner-collection.yml`.
*   `description`: (String) Description for this version.

**Optional Fields:**

*   `author`: (String) Can override collection author.
*   `version`: (String) Semantic version (e.g., "1.0.0"). *Note: SHI primarily uses the directory name for versioning, but including this field is good practice.*
*   `roles`: (Array) Defines software components or features users can enable/disable. See [Roles Definition](#roles-definition) below.
*   `configuration`: (Object) Defines custom UI fields. See [Configuration Fields Definition](#configuration-fields-definition) below.

**Example `provisioner.yml` (inside `1.0.0/`):**

```yaml
name: "My Custom Web Server"
type: "my_custom_webserver"
version: "1.0.0"
description: "Provisions Apache, MySQL, PHP."
author: "Your Name"
roles:
  - name: "install_apache"
    label: "Install Apache"
    description: "Installs Apache web server."
    defaultEnabled: true
    required: true
  - name: "install_mysql"
    label: "Install MySQL"
    description: "Installs MySQL database server."
    defaultEnabled: true
  - name: "install_php"
    label: "Install PHP"
    description: "Installs PHP scripting language."
    defaultEnabled: true
configuration:
  basicFields:
    - name: "php_version"
      type: "dropdown"
      label: "PHP Version"
      defaultValue: "8.1"
      options:
        - value: "8.0"
          label: "PHP 8.0"
        - value: "8.1"
          label: "PHP 8.1"
        - value: "8.2"
          label: "PHP 8.2"
  advancedFields:
    - name: "apache_port"
      type: "number"
      label: "Apache Port"
      defaultValue: 80
      min: 1
      max: 65535
```

## Templates

### `templates/Hosts.template.yml` (Required)

This is the most crucial template. SHI processes this file to generate the `Hosts.yml` file within the server instance directory. This generated `Hosts.yml` is typically used as the Ansible inventory or variable file.

You can use placeholders in the format `::VARIABLE_NAME::` which SHI will replace with values from the server configuration.

**Available Standard Variables:**

*   `::SERVER_HOSTNAME::`: The server hostname (e.g., `devserver1`).
*   `::SERVER_DOMAIN::`: The server domain/organization (e.g., `mydomain.local`).
*   `::SERVER_ORGANIZATION::`: Same as `SERVER_DOMAIN`.
*   `::SERVER_ID::`: The unique integer ID assigned by SHI.
*   `::RESOURCES_RAM::`: RAM in GB (e.g., `8.0`).
*   `::SERVER_MEMORY::`: RAM in GB (e.g., `8.0`).
*   `::RESOURCES_CPU::`: Number of CPU cores (e.g., `2`).
*   `::SERVER_CPUS::`: Number of CPU cores (e.g., `2`).
*   `::NETWORK_DHCP4::`: `true` or `false`.
*   `::SERVER_DHCP::`: `true` or `false`.
*   `::NETWORK_ADDRESS::`: Static IP address (if DHCP is false).
*   `::NETWORK_NETMASK::`: Static netmask (if DHCP is false).
*   `::NETWORK_GATEWAY::`: Static gateway (if DHCP is false).
*   `::NETWORK_DNS_NAMESERVER_1::` / `::NETWORK_DNS1::`: Primary DNS.
*   `::NETWORK_DNS_NAMESERVER_2::` / `::NETWORK_DNS2::`: Secondary DNS.
*   `::NETWORK_BRIDGE::`: Selected host bridge interface name.
*   `::DISABLE_BRIDGE_ADAPTER::`: `true` or `false`.
*   `::USER_EMAIL::`: User email from SHI config (if entered).
*   `::SYNC_METHOD::`: `rsync` or `scp`.
*   `::ENV_SETUP_WAIT::`: Wait time in seconds.

**Role Variables:**

For each role defined in `provisioner.yml`, SHI makes its enabled status available:

*   `::role_name::`: `true` or `false` (e.g., `::install_apache::`).

SHI also provides variables for associated installer files (if the role definition includes the `installers` block and files are located by the user):

*   `::ROLE_NAME_UPPER_INSTALLER::`: Filename of the main installer.
*   `::ROLE_NAME_UPPER_HASH::`: SHA256 hash of the main installer.
*   `::ROLE_NAME_UPPER_INSTALLER_VERSION::`: Version of the main installer.
*   `::ROLE_NAME_UPPER_FP_INSTALL::`: `true` if a fixpack is associated, `false` otherwise.
*   `::ROLE_NAME_UPPER_FP_INSTALLER::`: Filename of the fixpack.
*   `::ROLE_NAME_UPPER_FP_HASH::`: SHA256 hash of the fixpack.
*   `::ROLE_NAME_UPPER_FP_INSTALLER_VERSION::`: Version of the fixpack.
*   `::ROLE_NAME_UPPER_HF_INSTALL::`: `true` if a hotfix is associated, `false` otherwise.
*   `::ROLE_NAME_UPPER_HF_INSTALLER::`: Filename of the hotfix.
*   `::ROLE_NAME_UPPER_HF_HASH::`: SHA256 hash of the hotfix.
*   `::ROLE_NAME_UPPER_HF_INSTALLER_VERSION::`: Version of the hotfix.

*(Note: Replace `ROLE_NAME_UPPER` with the role name in uppercase, with hyphens converted to underscores, e.g., `INSTALL_APACHE_INSTALLER`)*

**Custom Configuration Variables:**

Any fields defined in the `configuration` section of `provisioner.yml` are available as `::field_name::`.

*   Example: `::php_version::`, `::apache_port::`

**Example `Hosts.template.yml`:**

```yaml
all:
  hosts:
    # Use FQDN for the host definition
    ::SERVER_HOSTNAME:::::SERVER_DOMAIN:::
      # Ansible connection variables
      ansible_host: ::NETWORK_ADDRESS::  # Assuming static IP or DHCP assigns predictably
      ansible_user: vagrant             # Default Vagrant user
      ansible_ssh_private_key_file: .vagrant/machines/default/virtualbox/private_key # Default Vagrant key location

  vars:
    # Server Basics
    server_hostname: ::SERVER_HOSTNAME::
    server_domain: ::SERVER_DOMAIN::
    server_ram_gb: ::SERVER_MEMORY::
    server_cpus: ::SERVER_CPUS::

    # Custom Config
    apache_port: ::apache_port::
    php_version_target: ::php_version::

    # Role Enablement
    install_apache: ::install_apache::
    install_mysql: ::install_mysql::
    install_php: ::install_php::

    # Example Installer Vars (if needed by Ansible)
    # apache_installer_file: ::INSTALL_APACHE_INSTALLER::
    # mysql_installer_hash: ::INSTALL_MYSQL_HASH::
```

## Ansible/Scripts

Place your Ansible playbooks, roles, or shell scripts within the version directory (e.g., in an `ansible/` or `scripts/` subdirectory). Your `Vagrantfile` (either the default one SHI generates or your custom template) should reference these scripts to perform the actual provisioning. Use the variables defined in the generated `Hosts.yml` within your Ansible playbooks.

## Testing Your Provisioner

1.  Create the directory structure and metadata files as described above.
2.  Use the **Settings -> Import Provisioner** feature in SHI to import your provisioner (using the "Import Collection" or "Import Version" tab with the local path).
3.  Create a new server instance using your imported provisioner type.
4.  Configure the server, including any custom fields and roles you defined.
5.  Start and provision the server.
6.  Check the **Console** output in SHI for errors during Vagrant and Ansible execution.
7.  Verify the VM is configured as expected (e.g., SSH into the VM, check installed software, access web services).

## Sharing Your Provisioner

Once tested, you can share your provisioner by:

*   Zipping the entire provisioner type directory (e.g., `my_custom_webserver/`) and sharing the zip file. Users import via "Import Collection".
*   Uploading the structure to a GitHub repository. Users import via "Import from GitHub".
