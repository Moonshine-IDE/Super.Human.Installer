---
layout: default
title: File Cache & Hashes
parent: Settings & Management # Updated parent title
nav_order: 2
has_children: false
---

# File Cache & Hashes Manager

The File Cache & Hashes Manager (`HashManagerPage.hx`) provides an interface for managing the local cache of installation files required by provisioners. It allows you to view, add, edit, and verify these files.

Access this page via **Settings -> Manage Installer Files**.

## Overview

Provisioners often require specific installer files (e.g., `.tar`, `.zip` files for Domino, Traveler, Verse) to perform software installation within the VMs. SHI maintains a local cache of these files to avoid repeated downloads and to verify their integrity. This manager helps organize these files and ensures the correct ones are used during provisioning.

## Features

### File Listing and Management

The manager displays all known installation files defined in the application's internal hash registry (`SuperHumanHashes.hx`) or added manually. The table shows:

*   **Filename**: The expected or actual filename of the cached installation file.
*   **Hash (SHA256)**: The expected cryptographic hash used to verify file integrity.
*   **Role**: The software component the file belongs to (e.g., `domino`, `traveler`, `verse`, `nomadweb`, `leap`, `domino-rest-api`).
*   **Type**: The type of file (`installer`, `hotfix`, `fixpack`).
*   **Version**: The expected version of the installation file.
*   **Status**:
    *   **Green Checkmark**: File exists in the cache directory and its SHA256 hash matches the expected hash.
    *   **Yellow Warning Icon**: File is missing from the cache directory.
    *   **Red Error Icon**: File exists, but its hash does *not* match the expected hash (indicating potential corruption or incorrect file).

### Adding/Locating Files

If a file is missing or incorrect (Warning/Error status):

1.  Click the **Locate File** button next to the entry.
2.  A file browser dialog will appear.
3.  Navigate to and select the correct installation file on your local system.
4.  SHI will:
    *   Copy the selected file into the cache directory.
    *   Calculate its SHA256 hash.
    *   Compare the calculated hash with the expected hash.
    *   Update the status icon accordingly.

*Note: Currently, there isn't a dedicated "Add New File" button for files not already known by the internal registry. New file definitions are typically added by updating `SuperHumanHashes.hx` or potentially through future provisioner metadata enhancements.*

### Editing Metadata (Not Implemented)

Editing metadata (Role, Type, Version, Hash) for existing entries directly through the UI is **not currently supported**. These details are typically managed within the application's code (`SuperHumanHashes.hx`).

### Downloading Missing Files (Not Implemented)

Directly downloading missing files from sources like HCL is **not currently implemented** within this interface. Files must be obtained manually and then added/located using the "Locate File" button.

## Cache Directory

*   **Show Cache Directory**: Clicking this button opens the system's file explorer to the location where SHI stores the cached installer files (`<AppStorage>/cache/`).
*   **Clear Cache**: This button removes *all* files from the cache directory. You will need to re-locate or re-download necessary files afterwards.

## File Verification

SHI relies on SHA256 hashes to ensure the integrity and correctness of installer files. When a provisioner needs a file, SHI checks the cache:

1.  Does the file exist?
2.  Does the file's SHA256 hash match the expected hash stored in the registry?

If both conditions are met, the file is used for provisioning. If the file is missing or the hash mismatches, provisioning for that role may fail.

## Relevant Files

*   `Source/superhuman/components/HashManagerPage.hx` - UI implementation for this page.
*   `Source/superhuman/server/cache/SuperHumanFileCache.hx` - Core cache management logic (locating files, verifying hashes).
*   `Source/superhuman/server/cache/SuperHumanCachedFile.hx` - Data structure for cached file information.
*   `Source/superhuman/config/SuperHumanHashes.hx` - Internal registry of known files, hashes, roles, types, and versions.
