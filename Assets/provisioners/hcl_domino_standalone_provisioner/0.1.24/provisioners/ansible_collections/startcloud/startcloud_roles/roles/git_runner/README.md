# Ansible Role: git_runner

Sets up a GitHub Actions self-hosted runner on your system. This role downloads the GitHub Actions runner, configures it with a token obtained from GitHub's API, and sets it up as a systemd service.

## Requirements

- Debian-based Linux system (Debian 12+ or Ubuntu 20.04+)
- GitHub API token with appropriate permissions
- Internet access to download the runner and communicate with GitHub

## Role Variables

### Required Variables

These must be set in your playbook or Hosts.yml:

```yaml
# GitHub API token (best stored in .secrets.yml)
git_runner_github_token: "{{ secrets.github_token }}"

# Organization OR repository (one must be specified)
git_runner_org: "your-org-name"           # For org-level runner
# OR
git_runner_repo: "owner/repo-name"        # For repo-level runner
```

### Optional Variables

Available in `defaults/main.yml`:

```yaml
# Runner configuration
git_runner_user: "{{ service_user | default('startcloud') }}"
git_runner_home: "{{ service_home_dir | default('/home/' + git_runner_user) }}"
git_runner_dir: "{{ git_runner_home }}/actions-runner"
git_runner_work_folder: "_work"

# Runner identity
git_runner_name: "runner-{{ ansible_hostname }}"
git_runner_labels: ["self-hosted", "Linux", "X64"]
git_runner_group_id: 1

# Runner version
git_runner_version: "latest"  # Or specific version like "2.311.0"

# Systemd service
git_runner_service_enabled: true
git_runner_service_name: "github-actions-runner"
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: all
  roles:
    - role: startcloud.startcloud_roles.git_runner
      vars:
        git_runner_org: "my-organization"
        git_runner_name: "production-runner"
        git_runner_labels: ["self-hosted", "linux", "production"]
```

## Running Ad-Hoc (Standalone Execution)

You can run this role ad-hoc outside of the Vagrant provisioning workflow to set up or reset a runner.

### Method 1: Using a Simple Playbook

Create `setup-runner.yml`:

```yaml
---
- name: Setup GitHub Actions Runner
  hosts: localhost
  connection: local
  become: true
  vars:
    git_runner_org: "your-organization"
    git_runner_name: "dev-runner"
    git_runner_labels: ["self-hosted", "linux", "x64"]
  
  roles:
    - startcloud.startcloud_roles.git_runner
```

Run with:
```bash
ansible-playbook setup-runner.yml -e "@.secrets.yml"
```

Or specify token directly:
```bash
ansible-playbook setup-runner.yml -e "git_runner_github_token=ghp_yourtoken"
```

### Method 2: One-Liner Command (No Playbook File Needed)

**Basic one-liner** (using token from .secrets.yml):
```bash
ansible localhost -m include_role -a name=startcloud.startcloud_roles.git_runner -e git_runner_org=my-org -e "@.secrets.yml" --become
```

**Complete example with all options**:
```bash
ansible localhost -m include_role -a name=startcloud.startcloud_roles.git_runner \
  -e git_runner_github_token=github_pat_TOKEN \
  -e git_runner_org=STARTcloud \
  -e git_runner_name=my-runner \
  -e git_runner_user=startcloud \
  -e git_runner_dir=/home/startcloud/actions-runner \
  -e "git_runner_labels=['self-hosted','linux','x64']" \
  -e git_runner_ephemeral=false \
  -e git_runner_version=latest \
  --become
```

**For repository-level runner**:
```bash
ansible localhost -m include_role -a name=startcloud.startcloud_roles.git_runner -e git_runner_github_token=github_pat_TOKEN -e git_runner_repo=owner/repo -e git_runner_name=repo-runner --become
```

**Ephemeral (one-job) runner**:
```bash
ansible localhost -m include_role -a name=startcloud.startcloud_roles.git_runner -e git_runner_org=STARTcloud -e git_runner_name=temp-runner -e git_runner_ephemeral=true -e git_runner_github_token=github_pat_TOKEN --become
```

### Method 3: Reset/Reinstall Runner

To completely reset and reinstall a runner, create `reset-runner.yml`:

```yaml
---
- name: Reset GitHub Actions Runner
  hosts: localhost
  connection: local
  become: true
  vars:
    git_runner_org: "your-organization"
    git_runner_user: "startcloud"
    git_runner_home: "/home/startcloud"
    git_runner_dir: "{{ git_runner_home }}/actions-runner"
  
  tasks:
    - name: Stop runner service if exists
      systemd:
        name: "actions.runner.*"
        state: stopped
      ignore_errors: true
    
    - name: Remove runner using svc.sh
      shell: |
        cd {{ git_runner_dir }}
        sudo ./svc.sh uninstall || true
      args:
        executable: /bin/bash
      ignore_errors: true
    
    - name: Remove runner directory
      file:
        path: "{{ git_runner_dir }}"
        state: absent
  
  roles:
    - startcloud.startcloud_roles.git_runner
```

Run with:
```bash
ansible-playbook reset-runner.yml -e "@.secrets.yml"
```

### Requirements for Ad-Hoc Execution

- Ansible installed on the target system
- startcloud_roles collection available in Ansible collections path
- GitHub token with appropriate permissions
- Root/sudo access for systemd service installation

## GitHub Token Permissions

Your GitHub token must be a **Fine-grained Personal Access Token** (not Classic PAT) with:

### For Organization Runners:
- Organization permissions → **Self-hosted runners** → **Read and Write access**

### For Repository Runners:
- Repository permissions → **Administration** → **Read and Write access**

## Systemd Service

The runner is installed as a systemd service using GitHub's svc.sh script. The service name follows this pattern:

```
actions.runner.<organization>.<runner-name>.service
```

For example, if your org is `STARTcloud` and runner name is `my-runner`, the service is:
```
actions.runner.STARTcloud.my-runner.service
```

**Managing the service:**

```bash
# Check status
sudo systemctl status actions.runner.STARTcloud.my-runner.service

# View logs
sudo journalctl -u actions.runner.STARTcloud.my-runner.service -f

# Restart service
sudo systemctl restart actions.runner.STARTcloud.my-runner.service

# Stop service
sudo systemctl stop actions.runner.STARTcloud.my-runner.service
```

**Using svc.sh helper:**

```bash
cd ~/actions-runner
sudo ./svc.sh status
sudo ./svc.sh stop
sudo ./svc.sh start
```

## Troubleshooting

### Runner not appearing in GitHub

1. Verify the GitHub token has correct permissions (Fine-grained PAT with write access)
2. Check systemd service status: `sudo systemctl status actions.runner.<org>.<name>.service`
3. View runner logs: `sudo journalctl -u actions.runner.<org>.<name>.service -f`
4. Check GitHub's runners page to see if it's registered but offline

### API call fails with 403 Forbidden

- Ensure you're using a **Fine-grained Personal Access Token**, not a Classic PAT
- Verify the token has **Read and Write** access (not just Read) to "Self-hosted runners"
- Check that the token hasn't expired

### Service not starting

- Check ownership: `ls -la ~/actions-runner`
- View service logs: `sudo journalctl -u actions.runner.<org>.<name>.service -f`
- Try manual start: `cd ~/actions-runner && sudo ./svc.sh start`

### Permission issues

- Ensure the runner user has proper permissions
- Check ownership of the runner directory: should be owned by the git_runner_user

## License

Apache

## Author Information

This role was created by MarkProminic for STARTCloud.

## Related Documentation

- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [JIT Runners API](https://docs.github.com/en/rest/actions/self-hosted-runners#create-configuration-for-a-just-in-time-runner-for-an-organization)
- [Security Hardening for Self-Hosted Runners](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)
