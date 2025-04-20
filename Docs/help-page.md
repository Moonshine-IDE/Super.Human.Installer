---
layout: default
title: Help & Support
nav_order: 9
has_children: false
---

# Help & Support

This page provides resources and guidance if you encounter issues or have questions about Super.Human.Installer (SHI).

## Troubleshooting Common Issues

Before seeking further help, please review the troubleshooting sections within the relevant documentation pages:

*   **[Server Management](vm-management#troubleshooting)**: For issues related to starting, stopping, provisioning, or connecting to VMs.
*   **[Provisioner Import](provisioner-import#troubleshooting-import-failures)**: For problems importing custom provisioners.
*   **[File Cache & Hashes](file-cache)**: For issues related to missing or invalid installer files.

**Key Troubleshooting Steps:**

1.  **Check Prerequisites**: Ensure compatible versions of VirtualBox, Vagrant, and Git are installed and functioning correctly ([Getting Started](getting-started#software-prerequisites)).
2.  **Review Console Output**: The server **Console** within SHI provides detailed logs from Vagrant and Ansible. Error messages here are crucial for diagnosis. Use the "Copy" button to easily share logs if needed.
3.  **Check SHI Logs**: For application-level errors, check the `current.txt` log file located in `<AppStorage>/logs/`. (`<AppStorage>` is the application's data directory, typically found in `~/Library/Application Support/` on macOS, `%APPDATA%` on Windows, or `~/.local/share/` on Linux). Click "Open Logs Directory" on the Support page (accessible via the main menu) for easy access.
4.  **Verify File Cache**: Ensure all required installer files for your selected roles are present and valid in the [File Cache & Hashes](file-cache) manager (Settings -> Manage Installer Files).
5.  **Network Configuration**: If experiencing VM network issues, double-check IP address settings, DHCP configuration, and the selected Bridge Adapter in the server's Advanced Configuration.

## External Resources

*   **HCL Domino Documentation**: Refer to official HCL documentation for Domino-specific configuration and troubleshooting.
*   **Vagrant Documentation**: [https://developer.hashicorp.com/vagrant/docs](https://developer.hashicorp.com/vagrant/docs)
*   **VirtualBox Documentation**: [https://www.virtualbox.org/wiki/Documentation](https://www.virtualbox.org/wiki/Documentation)
*   **Ansible Documentation**: [https://docs.ansible.com/](https://docs.ansible.com/)
*   **YAML Syntax**: [https://yaml.org/spec/1.2/spec.html](https://yaml.org/spec/1.2/spec.html)

## Reporting Issues & Requesting Features

If you encounter a bug within Super.Human.Installer itself, or have a suggestion for a new feature:

1.  **Search Existing Issues**: Check the [GitHub Issue Tracker](https://github.com/Prominic/Super.Human.Installer/issues) to see if a similar issue has already been reported.
2.  **Create a New Issue**: If your issue is new, click the "New Issue" button on GitHub. Select the appropriate template (Bug report or Feature request).
3.  **Provide Details**: Include the following information:
    *   SHI Version (Help -> About)
    *   Operating System (Windows, macOS, Linux version)
    *   VirtualBox Version
    *   Vagrant Version
    *   Clear description of the problem or feature request.
    *   Steps to reproduce the issue (for bugs).
    *   Relevant logs from the SHI Console or `current.txt` log file. (Please redact any sensitive information before posting logs).

## Contributing

Contributions to the documentation or codebase are welcome! Please refer to the main [README.md](https://github.com/Prominic/Super.Human.Installer/blob/main/README.md) on the GitHub repository for contribution guidelines.

## Relevant Files

*   `Source/superhuman/components/HelpPage.hx` - UI implementation for the in-app Help page.
*   `Source/superhuman/components/SupportPage.hx` (Genesis Framework) - UI for log access and issue reporting links.
