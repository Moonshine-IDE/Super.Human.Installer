---
layout: default
title: Server Management # Renamed to match link
nav_order: 4 # Adjusted order
has_children: false
---

# Server Management

Super.Human.Installer (SHI) provides a comprehensive interface for creating and managing the virtual machines (VMs) that host your server environments.

## Server Management Interface (`ServerPage.hx`)

The main "Servers" page is your central hub. It displays all configured server instances, their current status (obtained from Vagrant and VirtualBox), and provides controls for managing their lifecycle.

![Server Management Interface](../assets/start-screen.png)

### Server States

Servers managed by SHI can exist in several states:

*   **Unconfigured**: Initial state after adding but before saving basic configuration.
*   **Ready**: Configuration saved, but the VM has not been created yet.
*   **Stopped**: The VM exists but is not currently running.
*   **Running**: The VM is active and operational.
*   **Suspended**: The VM's state has been saved, and it can be quickly resumed.
*   **Aborted**: The VM was terminated unexpectedly.
*   **Error**: The VM encountered an error during startup or provisioning (check Console).
*   *(Various intermediate states like "Starting", "Stopping", "Provisioning" are also shown)*

### Server Actions

Buttons appear next to each server, offering actions based on its current state:

*   **Start** (`ServerStatus.Stopped`, `ServerStatus.Suspended`, `ServerStatus.Ready`, `ServerStatus.Aborted`): Creates the VM if it doesn't exist (`Ready` state), then starts or resumes the VM. May trigger provisioning depending on settings.
*   **Stop** (`ServerStatus.Running`): Gracefully shuts down the running VM using `vagrant halt`.
*   **Suspend** (`ServerStatus.Running`): Pauses the VM using `vagrant suspend`, saving its state.
*   **Provision** (`ServerStatus.Running`, `ServerStatus.Stopped`): Executes the Ansible provisioning scripts defined by the server's provisioner and enabled roles. Ensures the VM is running first.
*   **Destroy** (`Any state except Unconfigured`): Completely removes the VM from VirtualBox using `vagrant destroy`. **This is irreversible.**
*   **Configure** (`Any state`): Opens the server's configuration page (`ConfigPage`, `AdditionalServerPage`, or `DynamicConfigPage`).
*   **Delete** (`Any state`): Removes the server configuration *from SHI only*.
    *   "Delete Server": Removes the entry from SHI but leaves the VM and its files intact in VirtualBox/Vagrant and on disk.
    *   "Delete Server and Files": Removes the entry from SHI *and* deletes the server's working directory from the host machine. **Does not destroy the VM in VirtualBox.** Use "Destroy" first if you want to remove the VM completely.

## Creating and Configuring Servers

See the **[Creating & Configuring Servers](creating-and-configuring-servers)** page for detailed steps.

## Managing VM Lifecycle

### Starting a Server

1.  Select the server in the list (must be in a state allowing Start).
2.  Click the "Start" button (play icon).
3.  SHI executes `vagrant up`.
4.  Vagrant interacts with VirtualBox to create/start the VM.
5.  If provisioning is needed/configured, Vagrant runs the Ansible scripts.
6.  Status updates in the UI, eventually showing "Running".

### Stopping a Server

1.  Select a running server.
2.  Click the "Stop" button (stop icon).
3.  SHI executes `vagrant halt`.
4.  Vagrant sends a shutdown signal to the guest OS.
5.  Status updates to "Stopped".

### Suspending a Server

1.  Select a running server.
2.  Click the "Suspend" button (pause icon).
3.  SHI executes `vagrant suspend`.
4.  VirtualBox saves the VM's current state to disk.
5.  Status updates to "Suspended".
6.  Use "Start" to resume the VM from its saved state.

## File Synchronization

SHI synchronizes files between the host machine (specifically, the server's working directory) and the guest VM. This is configured via Vagrant, typically using shared folders. The method can be influenced via the **Settings -> File Synchronization** option:

*   **Rsync**: Generally faster, especially for large or numerous files. Requires `rsync` on the host. Default on macOS/Linux. May require manual setup on Windows.
*   **SCP**: Uses the Secure Copy Protocol over SSH. More broadly compatible but potentially slower. A reliable fallback.

## Connecting to VMs

SHI provides convenient buttons for accessing your server:

*   **Web**: Opens the server's primary web URL (if defined and detected) in your default browser.
*   **SSH**: Opens a new terminal window connected to the VM via `vagrant ssh`.
*   **FTP**: Opens the configured FTP client (like FileZilla, set up in Settings) connected to the server (requires FTP role/configuration).
*   **Console**: Opens a panel within SHI showing the live console output for the selected server's current or last operation (Start, Provision, etc.). Essential for troubleshooting.
*   **Folder**: Opens the server's working directory on your host machine in the system's file explorer. This directory contains the `Hosts.yml`, and other files used to manage the VM.

## Troubleshooting

*   **VM Fails to Start/Provision**: Check the **Console** output for specific errors from Vagrant, VirtualBox, or Ansible. Ensure VirtualBox & Vagrant are installed correctly and running. Verify required installer files are present and valid in the [File Cache](file-cache).
*   **Network Issues**: Ensure the VM's configured IP address doesn't conflict with other devices on your network. Check the selected **Bridge Adapter** in Advanced Configuration if not using DHCP.
*   **File Sync Errors**: Check permissions on the host directory. If using Rsync on Windows, ensure it's correctly installed and in the system PATH. Consider switching to SCP in Settings if Rsync issues persist.
*   **"Aborted" State**: This usually means the VM was terminated unexpectedly. Try starting it again. If it persists, the VM image might be corrupted, requiring a `Destroy` and then `Start` to recreate it.

## Relevant Files

*   [Source/superhuman/components/ServerPage.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/components/ServerPage.hx) - Main server management UI.
*   [Source/superhuman/components/ServerList.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/components/ServerList.hx) - Renders the list of servers.
*   [Source/superhuman/managers/ServerManager.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/managers/ServerManager.hx) - Core server state and lifecycle logic.
*   [Source/superhuman/server/Server.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/Server.hx) - Represents a single server instance.
*   [Source/superhuman/server/CombinedVirtualMachine.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Source/superhuman/server/CombinedVirtualMachine.hx) - Holds combined state from Vagrant/VirtualBox.
*   [Genesis/Source/prominic/sys/applications/hashicorp/Vagrant.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Genesis/Source/prominic/sys/applications/hashicorp/Vagrant.hx) - Vagrant CLI wrapper.
*   [Genesis/Source/prominic/sys/applications/oracle/VirtualBox.hx](https://github.com/Moonshine-IDE/Super.Human.Installer/blob/master/Genesis/Source/prominic/sys/applications/oracle/VirtualBox.hx) - VirtualBox CLI wrapper.
