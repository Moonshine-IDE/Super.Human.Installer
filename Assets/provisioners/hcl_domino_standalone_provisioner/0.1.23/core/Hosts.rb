# coding: utf-8
# Load the CoreProvisioner Version Module
require File.expand_path("#{File.dirname(__FILE__)}/version.rb")
require 'open3'
require 'yaml'
require 'fileutils'


if File.file?("#{File.dirname(__FILE__)}/../version.rb")
  # Load the Current Provisioner Version Module
  require File.expand_path("#{File.dirname(__FILE__)}/../version.rb")
end

# This class takes the Hosts.yaml and set's the neccessary variables to run provider specific sequences to boot a VM.
class Hosts
  def Hosts.configure(config, settings)
    secrets = Hosts.load_secrets

    ENV['ATLAS_TOKEN'] = secrets['ATLAS_TOKEN'] if secrets && secrets.key?('ATLAS_TOKEN')

    # Main loop to configure VM
    settings['hosts'].each_with_index do |host, index|

      ENV['VAGRANT_NO_PARALLEL'] = 'yes'
      if host['settings'].has_key?('parallel') && host['settings']['parallel']
        ENV['VAGRANT_NO_PARALLEL'] = 'no'
      end
      
      ENV['VAGRANT_SERVER_URL'] = host['settings']['box_url'] if host['settings'].has_key?('box_url')

      provider = host['settings']['provider_type']
      config.vm.define "#{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}" do |server|
        server.vm.box = host['settings']['box']
        config.vm.box_url = host['settings']['box_url'].to_s.empty? ? "https://vagrantcloud.com/#{host['settings']['box']}" : "#{host['settings']['box_url']}/#{host['settings']['box']}"
        server.vm.box_version = host['settings']['box_version']
        server.vm.boot_timeout = host['settings']['setup_wait']
        server.ssh.username = host['settings']['vagrant_user']
        #server.ssh.password = host['settings']['vagrant_user_pass']
        default_ssh_key = "./core/ssh_keys/id_rsa"
        vagrant_ssh_key = host['settings']['vagrant_user_private_key_path']
        server.ssh.private_key_path = File.exist?(vagrant_ssh_key) ? [vagrant_ssh_key, default_ssh_key] : default_ssh_key
        server.ssh.insert_key = false # host['settings']['vagrant_ssh_insert_key'], Note we are no longer automatically forcing the key in via Vagrants SSH insertion function
        server.ssh.forward_agent = host['settings']['vagrant_ssh_forward_agent']
        server.ssh.keep_alive = host['settings'].key?('vagrant_ssh_keep_alive') ? host['settings']['vagrant_ssh_keep_alive'] : true
        config.vm.communicator = :ssh
        config.winrm.username = host['settings']['vagrant_user']
        config.winrm.password = host['settings']['vagrant_user_pass']
        config.winrm.timeout = host['settings']['setup_wait']
        config.winrm.retry_delay = 30
        config.winrm.retry_limit = 1000

        if Vagrant::Util::Platform.windows?  || Vagrant::Util::Platform.cygwin? || Vagrant::Util::Platform.wsl?
          path_VBoxManage = "VBoxManage.exe"
        elsif Vagrant::Util::Platform.darwin? || Vagrant::Util::Platform.linux?  || Vagrant::Util::Platform.bsd? || Vagrant::Util::Platform.solaris?
          path_VBoxManage = "VBoxManage"
        end

        ## Networking
        ## For every Network block in Hosts.yml, and if its not empty
        if host.has_key?('networks') and !host['networks'].empty?
          ## This tells Virtualbox to set the Nat network so that we can avoid IP conflicts and more easily identify networks
          ## This Nic cannot be removed which is why its not in the loop below
#          config.vm.provider "virtualbox" do |network_provider|
#            # https://github.com/Moonshine-IDE/Super.Human.Installer/issues/116
#            network_provider.customize ['modifyvm', :id, '--natnet1', '10.244.244.0/24']
#          end

          ## Loop over each block, with an index so that we can use the ordering to specify interface number
          host['networks'].each_with_index do |network, netindex|
              ## Get the bridge device the user specifies, if none selected, we need to try our best to get the best one (for every OS: Mac, Windows, and Linux)
              bridge = network['bridge'] if defined?(network['bridge'])
              bridge = get_bridge_interface(path_VBoxManage) if bridge.nil? && provider == 'virtualbox'

              ## We then take those variables, and hopefully have the best connection to use and then pass it to vagrant so it can create the network adapters.
              if network['type'] == 'host'
                server.vm.network "private_network",
                  bridge: network['bridge'],
                  ip: network['address'],
                  gateway: network['gateway'],
                  netmask: network['netmask'],
                  type: 'dhcp',
                  dhcp: network['dhcp4'],
                  dhcp4: network['dhcp4'],
                  dhcp6: network['dhcp6'],
                  auto_config: network['autoconf'],
                  mac: provider == 'virtualbox' ? network['mac'].tr(':', '') : network['mac'],
                  nic_type: network['nic_type'],
                  nictype: network['type'],
                  nic_number: netindex,
                  managed: network['is_control'],
                  vlan: network['vlan'],
                  dns: network['dns'],
                  provisional: network['provisional'],
                  route: network['route']
                  #name: 'core_provisioner_network'
              end
              if network['type'] == 'external'
                server.vm.network "public_network",
                  bridge: bridge,
                  ip: network['address'],
                  gateway: network['gateway'],
                  netmask: network['netmask'],
                  dhcp: network['dhcp4'],
                  dhcp4: network['dhcp4'],
                  dhcp6: network['dhcp6'],
                  auto_config: network['autoconf'],
                  mac: provider == 'virtualbox' ? network['mac'].tr(':', '') : network['mac'],
                  nic_type: network['nic_type'],
                  nictype: network['type'],
                  nic_number: netindex,
                  managed: network['is_control'],
                  vlan: network['vlan'],
                  dns: network['dns'],
                  provisional: network['provisional'],
                  route: network['route']
              end
          end
        end

        ##### Begin Virtualbox Configurations #####
        # Save MAC addresses after VM is created and update Hosts.yml if needed
        config.trigger.after :up do |trigger|
          trigger.info = "Checking and updating network interface MAC addresses in Hosts.yml..."
          trigger.ruby do |env, machine|
            # Only run this for VirtualBox provider
            if host['settings']['provider_type'] == 'virtualbox'
              vm_name = "#{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}"
              
              # Get VM info from VirtualBox
              vm_info = `#{path_VBoxManage} showvminfo "#{vm_name}" --machinereadable`
              
              # Extract MAC addresses for each adapter
              mac_addresses = {}
              vm_info.scan(/macaddress(\d+)="(.+?)"/).each do |adapter_num, mac|
                mac_addresses[adapter_num.to_i] = mac.upcase
              end
              
              # Check if we need to update Hosts.yml
              hosts_yml_path = File.join(Dir.pwd, 'Hosts.yml')
              if File.exist?(hosts_yml_path)
                # Read the file line by line
                lines = File.readlines(hosts_yml_path)
                
                # Track if we're in the right host section
                in_current_host = false
                in_networks = false
                current_network_index = -1
                needs_update = false
                
                # Process each line
                lines.each_with_index do |line, i|
                  # Check if we're entering a host section
                  if line.strip == '-' && lines[i+1] && lines[i+1].strip.start_with?('settings:')
                    in_current_host = false
                    in_networks = false
                    current_network_index = -1
                  end
                  
                  # Check if we're in the settings section of the current host
                  if !in_current_host && line.strip.start_with?('hostname:') && line.include?(host['settings']['hostname'])
                    in_current_host = true
                  end
                  
                  # Check if we're entering the networks section of the current host
                  if in_current_host && line.strip == 'networks:'
                    in_networks = true
                    current_network_index = -1
                  end
                  
                  # Check if we're starting a new network entry
                  if in_networks && line.strip == '-'
                    current_network_index += 1
                  end
                  
                  # Check if this line contains a MAC address set to 'auto'
                  if in_networks && current_network_index >= 0 && line.strip.start_with?('mac:') && (line.include?('auto') || line.strip == 'mac:')
                    adapter_num = current_network_index + 2  # +2 because adapter 1 is NAT
                    if mac_addresses.has_key?(adapter_num)
                      formatted_mac = mac_addresses[adapter_num].scan(/../).join(':')
                      indent = line[/\A\s*/]
                      lines[i] = "#{indent}mac: #{formatted_mac}\n"
                      needs_update = true
                      puts "Updated MAC address for network #{current_network_index} to #{formatted_mac}"
                    end
                  end
                end
                
                # Write updated Hosts.yml if changes were made
                if needs_update
                  File.open(hosts_yml_path, 'w') do |file|
                    file.write(lines.join)
                  end
                  puts "Updated Hosts.yml with actual MAC addresses while preserving comments"
                end
              end
            end
          end
        end
        ##### Disk Configurations #####
        ## https://sleeplessbeastie.eu/2021/05/10/how-to-define-multiple-disks-inside-vagrant-using-virtualbox-provider/
        disks_directory = File.join("./", "disks")

        ## Create Disks
        config.trigger.before :up do |trigger|
          if host.has_key?('disks') && host['disks'].is_a?(Hash) && host['disks'].has_key?('additional_disks') && !host['disks']['additional_disks'].nil? && provider == 'virtualbox'
            trigger.name = "Creating disks"
            trigger.ruby do
              unless File.directory?(disks_directory)
                FileUtils.mkdir_p(disks_directory)
              end

              host['disks']['additional_disks'].each_with_index do |disks, diskindex|
                local_disk_filename = File.join(disks_directory, "#{disks['volume_name']}.vdi")
                unless File.exist?(local_disk_filename)
                  disk_size_gb = disks['size'].match(/(\d+(\.\d+)?)/)[0].to_f
                  disk_size_mb = (disk_size_gb * 1024).to_i
                  puts "Creating \"#{disks['volume_name']}\" disk with size \"#{disk_size_mb}\" MB (#{disk_size_gb} GB)"
                  system("#{path_VBoxManage} createmedium --filename #{local_disk_filename} --size #{disk_size_mb} --format VDI")
                end
              end
            end
          end
        end

        # Create storage controller on first run
        if host.has_key?('disks') && host['disks'].is_a?(Hash) && host['disks'].has_key?('additional_disks') && !host['disks']['additional_disks'].nil? && provider == 'virtualbox'
          unless File.directory?(disks_directory)
            config.vm.provider "virtualbox" do |storage_provider|
              host['disks']['additional_disks'].each_with_index do |disks, diskindex|
                if disks['driver'] == "virtio-scsi"
                  storage_provider.customize ["storagectl", :id, "--name", "VirtIO Controller", "--add", "virtio-scsi", '--hostiocache', 'off']

                  break
                end
              end
            end
          end
        end

        # attach storage devices
        if host.has_key?('disks') && host['disks'].is_a?(Hash) && host['disks'].has_key?('additional_disks') && !host['disks']['additional_disks'].nil? && provider == 'virtualbox'
          config.vm.provider "virtualbox" do |storage_provider|
            host['disks']['additional_disks'].each_with_index do |disks, diskindex|
              local_disk_filename = File.join(disks_directory, "#{disks['volume_name']}.vdi")
              unless File.exist?(local_disk_filename)
                storage_provider.customize ['storageattach', :id, '--storagectl', "VirtIO Controller", '--port', disks['port'], '--device', 0, '--type', 'hdd', '--medium', local_disk_filename]
              end
            end
          end
        end

        # Cleanup Disks after "destroy" action
        config.trigger.after :destroy do |trigger|
          if host.has_key?('disks') && host['disks'].is_a?(Hash) && host['disks'].has_key?('additional_disks') && !host['disks']['additional_disks'].nil? && provider == 'virtualbox'
            trigger.name = "Cleanup operation"
            trigger.ruby do
              # the following loop is now obsolete as these files will be removed automatically as machine dependency
              host['disks']['additional_disks'].each_with_index do |disks, diskindex|
                local_disk_filename = File.join(disks_directory, "#{disks['volume_name']}.vdi")
                if File.exist?(local_disk_filename)
                  puts "Deleting \"#{disks['volume_name']}\" disk"
                  system("#{path_VBoxManage} closemedium disk #{local_disk_filename} --delete")
                end
              end
              if File.exist?(disks_directory)
                FileUtils.rmdir(disks_directory)
              end
            end
          end
        end

        server.vm.provider :virtualbox do |vb|
          if host['settings']['memory'].to_s =~ /gb|g|/
            vm_memory = 1024 * host['settings']['memory'].to_s.tr('^0-9', '').to_i
          elsif host['settings']['memory'] =~ /mb|m|/
            vm_memory = host['settings']['memory'].tr('^0-9', '')
          end
          vb.name = "#{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}"
          vb.gui = host['settings']['show_console']
          vb.customize ['modifyvm', :id, '--ostype', host['settings']['os_type']]
          vb.customize ["modifyvm", :id, "--vrdeport", host['settings']['consoleport']]
          vb.customize ["modifyvm", :id, "--vrdeaddress", host['settings']['consolehost']]
          vb.customize ["modifyvm", :id, "--cpus", host['settings']['vcpus']]
          vb.customize ["modifyvm", :id, "--memory", vm_memory ]
          vb.customize ["modifyvm", :id, "--firmware", 'efi'] if host['settings']['firmware_type'] == 'UEFI'
          vb.customize ['modifyvm', :id, "--vrde", 'on']
          vb.customize ['modifyvm', :id, "--natdnsproxy1", 'off']
          vb.customize ['modifyvm', :id, "--natdnshostresolver1", 'off']
          vb.customize ['modifyvm', :id, "--accelerate3d", 'off']
          vb.customize ['modifyvm', :id, "--vram", '256']
          vb.customize ['modifyvm', :id, '--macaddress1', '00FF00FF00FF']

          if host.has_key?('roles') and !host['roles'].empty?
            host['roles'].each do |rolefwds|
              if rolefwds.has_key?('port_forwards') and !rolefwds.empty?
                rolefwds['port_forwards'].each_with_index do |param, index|
                  config.vm.network "forwarded_port", guest: param['guest'], host: param['host'], host_ip: param['ip']
                end
              end
            end
          end

          if host.has_key?('vbox') and !host['vbox'].empty?
            if host['vbox'].has_key?('directives') and !host['vbox']['directives'].empty?
              host['vbox']['directives'].each do |param|
                vb.customize ['modifyvm', :id, "--#{param['directive']}", param['value']]
              end
            end
          end
        end
        ##### End Virtualbox Configurations #####

        ##### Begin ZONE type Configurations #####
        if provider == 'zones'
          server.vm.provider :zone do |vm|
            vm.hostname                             = "#{host['settings']['subdomain']}.#{host['settings']['domain']}"
            vm.name                                 = "#{host['settings']['partition_id']}--#{host['settings']['subdomain']}.#{host['settings']['domain']}"
            vm.partition_id                         = host['settings']['server_id']

            vm.vagrant_cloud_creator                = host['settings']['cloud_creator']
            vm.boxshortname                         = host['settings']['boxshortname']

            vm.cloud_init_password                  = host['settings']['vagrant_user_pass']
            vm.vagrant_user_private_key_path        = host['settings']['vagrant_user_private_key_path']
            vm.vagrant_user                         = host['settings']['vagrant_user']
            vm.vagrant_user_pass                    = host['settings']['vagrant_user_pass']
            vm.os_type                              = host['settings']['os_type']
            vm.firmware_type                        = host['settings']['firmware_type']
            vm.setup_wait                           = host['settings']['setup_wait']
            vm.consoleport                          = host['settings']['consoleport']
            vm.consolehost                          = host['settings']['consolehost']
            vm.memory                               = host['settings']['memory']
            vm.cpus                                 = host['settings']['vcpus']
            vm.dns                                  = host['networks']
            vm.boot                                 = host['disks']['boot']
            vm.additional_disks                     = host['disks']['additional_disks']
            vm.cdroms                               = host['disks']['cdroms']
            vm.autoboot                             = host['zones']['autostart']
            vm.brand                                = host['zones']['brand']
            vm.zunlockbootkey                       = host['zones']['zunlockbootkey']
            vm.zunlockboot                          = host['zones']['zunlockboot']
            vm.cpu_configuration                    = host['zones']['cpu_configuration']
            vm.complex_cpu_conf                     = host['zones']['complex_cpu_conf']
            vm.console_onboot                       = host['zones']['console_onboot']
            vm.console                              = host['zones']['console']
            vm.override                             = host['zones']['override']
            vm.acpi                                 = host['zones']['acpi']
            vm.shared_disk_enabled                  = host['zones']['shared_lofs_disk_enabled']
            vm.shared_dir                           = host['zones']['shared_lofs_dir']
            vm.custom_ci_web_root                   = host['zones']['custom_ci_web_root']
            vm.ci_port                              = host['zones']['ci_port']
            vm.ci_listen                            = host['zones']['ci_listen']
            vm.custom_ci                            = host['zones']['custom_ci']
            vm.allowed_address                      = host['zones']['allowed_address']
            vm.diskif                               = host['zones']['diskif']
            vm.netif                                = host['zones']['netif']
            vm.hostbridge                           = host['zones']['hostbridge']
            vm.clean_shutdown_time                  = host['zones']['clean_shutdown_time']
            vm.vmtype                               = host['zones']['vmtype']
            vm.booted_string                        = host['zones']['booted_string']
            vm.lcheck                               = host['zones']['lcheck_string']
            vm.alcheck                              = host['zones']['alcheck_string']
            vm.debug_boot                           = host['zones']['debug_boot']
            vm.debug                                = host['zones']['debug']
            vm.snapshot_script                      = host['zones']['snapshot_script']
            vm.cloud_init_enabled                   = host['zones']['cloud_init_enabled']
            vm.cloud_init_dnsdomain                 = host['zones']['cloud_init_dnsdomain']
            vm.cloud_init_conf                      = host['zones']['cloud_init_conf']
            vm.safe_restart                         = host['zones']['safe_restart']
            vm.safe_shutdown                        = host['zones']['safe_shutdown']
            vm.setup_method                         = host['zones']['setup_method']
            vm.on_demand_vnics                      = host['zones']['on_demand_vnics']
          end
        end
        ## End Vagrant-Zones Configurations

        if host['vars'].has_key?('git_vault_password')
          Hosts.write_results_file(host['vars']['git_vault_password'], 'provisioners/ansible/git_vault_password', false)
        end

        # Register shared folders
        if host.has_key?('folders')
          host['folders'].each do |folder|
            mount_opts = folder['type'] == folder['type'] ? ['actimeo=1'] : []
            server.vm.synced_folder "#{folder['map']}", "#{folder ['to']}",
            type: folder['type'],
            map: "#{folder['map']}",
            to: "#{folder['to']}",
            owner: folder['owner'] ||= host['settings']['vagrant_user'],
            group: folder['group'] ||= host['settings']['vagrant_user'],
            mount_options: mount_opts,
            automount: true,
            scp__args: folder['args'],
            rsync__args: folder['args'] ||= ["--verbose", "--archive", "-z", "--copy-links"],
            rsync__chown: folder['chown'] ||= 'false',
            create: folder['create'] ||= 'false',
            rsync__rsync_ownership: folder['rsync_ownership'] ||= 'true',
            disabled: folder['disabled'] ||= false
          end
        end

        # Begin Provisioning Sequences
        if host.has_key?('provisioning') and !host['provisioning'].nil?
          # Add Branch Files to Vagrant Share on VM Change to Git folders to pull
          if host['provisioning'].has_key?('role') && host['provisioning']['role']['enabled']
            scriptsPath = File.dirname(__FILE__) + '/scripts'
            server.vm.provision 'shell' do |s|
              s.path = scriptsPath + '/add-role.sh'
              s.args = [host['provisioning']['role']['name'], host['provisioning']['role']['git_url'] ]
            end
          end

          # Run the shell provisioners defined in hosts.yml
          if host['provisioning'].has_key?('shell') && host['provisioning']['shell']['enabled']
            host['provisioning']['shell']['scripts'].each do |file|
                server.vm.provision 'shell', path: file
            end
          end

          # Run the Ansible Provisioners -- You can pass Host.yaml variables to Ansible via the Extra_vars variable as noted below.
          ## If Ansible is not available on the host and is installed in the template you are spinning up, use 'ansible-local'
          if host['provisioning'].has_key?('ansible') && host['provisioning']['ansible']['enabled']
            host['provisioning']['ansible']['playbooks'].each do |playbooks|
              if playbooks.has_key?('local')
                playbooks['local'].each do |localplaybook|
                  run_value = case localplaybook['run']
                    when 'always'
                      :always
                    when 'not_first'
                      File.exist?(File.join(Dir.pwd, 'results.yml')) ? :always : :never
                    else
                      :once
                    end

                  server.vm.provision :ansible_local, run: run_value do |ansible|
                    ansible.playbook = localplaybook['playbook']
                    ansible.compatibility_mode = localplaybook['compatibility_mode'].to_s
                    ansible.install_mode = "pip" if localplaybook['install_mode'] == "pip"
                    ansible.verbose = localplaybook['verbose']
                    ansible.config_file = "/vagrant/ansible/ansible.cfg"
                    ansible.galaxy_roles_path = "/vagrant"

                    ansible.extra_vars = {
                      settings: host['settings'],
                      networks: host['networks'],
                      disks: host['disks'],
                      secrets: secrets,
                      role_vars: host['vars'],
                      provision_roles: host['roles'],
                      provision_pre_tasks: host['pre_tasks'],
                      provision_post_tasks: host['post_tasks'],
                      playbook_collections: localplaybook['collections'],
                      core_provisioner_version: CoreProvisioner::VERSION,
                      provisioner_name: Provisioner::NAME,
                      provisioner_version: Provisioner::VERSION,
                      ansible_winrm_server_cert_validation: "ignore",
                      ansible_callbacks_enabled:localplaybook['callbacks'],
                      ansible_ssh_pipelining:localplaybook['ssh_pipelining'],
                      ansible_python_interpreter:localplaybook['ansible_python_interpreter']}
                    if localplaybook['remote_collections']
                      ansible.galaxy_role_file = "/vagrant/ansible/requirements.yml"
                      ansible.galaxy_roles_path = "/vagrant/ansible/ansible_collections"
                    end
                  end
                end
              end

              ## If Ansible is available on the host or is not installed in the template you are spinning up, use 'ansible'
              if playbooks.has_key?('remote')
                playbooks['remote'].each do |remoteplaybook|
                  run_value = case remoteplaybook['run']
                    when 'always'
                      :always
                    when 'once'
                      File.exist?(File.join(Dir.pwd, 'results.yml')) ? :never : :once
                    when 'not_first'
                      File.exist?(File.join(Dir.pwd, 'results.yml')) ? :always : :never
                    else
                      :once
                    end
                  server.vm.provision :ansible, run: run_value do |ansible|
                    ansible.playbook = remoteplaybook['playbook']
                    ansible.compatibility_mode = remoteplaybook['compatibility_mode'].to_s
                    ansible.verbose = remoteplaybook['verbose']
                    ansible.extra_vars = {
                      settings: host['settings'],
                      networks: host['networks'],
                      disks: host['disks'],
                      secrets: secrets,
                      role_vars: host['vars'],
                      provision_roles: host['roles'],
                      playbook_collections: remoteplaybook['collections'],
                      core_provisioner_version: CoreProvisioner::VERSION,
                      provisioner_name: Provisioner::NAME,
                      provisioner_version: Provisioner::VERSION,
                      ansible_winrm_server_cert_validation: "ignore",
                      ansible_callbacks_enabled:localplaybook['callbacks'],
                      ansible_ssh_pipelining:remoteplaybook['ssh_pipelining'],
                      ansible_python_interpreter:remoteplaybook['ansible_python_interpreter']
                    }
                    if remoteplaybook['remote_collections']
                      ansible.galaxy_role_file = "requirements.yml"
                      ansible.galaxy_roles_path = "./ansible/ansible_collections"
                    end
                  end
                end
              end
            end
          end

          # Run the Docker-Compose provisioners defined in hosts.yml
          if host['provisioning'].has_key?('docker') && host['provisioning']['docker']['enabled']
            server.vm.provision 'docker'
            if host['provisioning']['docker'].has_key?('docker-compose')
              host['provisioning']['docker']['docker_compose'].each do |file|
                server.vm.provision :docker_compose, yml: file, run: "always"
              end
            end
          end
        end
      end

      # Hook to run after destroy to clean up artifacts.
      if provider == 'virtualbox'
        config.trigger.after :destroy do |trigger|
          trigger.info = "Deleting cached files"
          files_to_delete = [
            '.vagrant/done.txt',
            '.vagrant/provisioned-adapters.yml',
            'results.yml',
            host['settings']['vagrant_user_private_key_path']
          ]
          trigger.ruby do
            Hosts.delete_files(trigger, files_to_delete)
          end
        end
      end

      ## Syncback
      if host.has_key?('folders') && Vagrant.has_plugin?("vagrant-scp-sync")
        prefix = "==> #{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}:"
        host['folders'].each do |folder|
          next unless folder['syncback']
          config.trigger.after :rsync, type: :command do |trigger|
            trigger.info = "Using SCP to sync from Guest to Host"
            trigger.ruby do |env, machine|
              guest_path = folder['to']
              host_path = folder['map'].split(/(?<=\/)[^\/]*$/).last
              transfer_cmd = "vagrant scp :#{guest_path} #{host_path}"
              puts "#{ prefix } #{ transfer_cmd }"
              system(transfer_cmd)
            end
          end
        end
      end

      ## Save variables to .vagrant directory
      if host.has_key?('networks') && host['settings']['provider_type'] == 'virtualbox' &&  host['settings']['post_provision']
        host['networks'].each_with_index do |network, netindex|
          config.trigger.after [:up] do |trigger|
            trigger.info = "Post-Provisioning Vagrant Operations"
            trigger.ruby do |env, machine|
              prefix = "==> #{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}:"
              puts "#{ prefix } This server has been provisioned with core_provisioner v#{CoreProvisioner::VERSION}"
              puts "#{ prefix } https://github.com/STARTcloud/core_provisioner/releases/tag/v#{CoreProvisioner::VERSION}"
              puts "#{ prefix } This server has been provisioned with #{Provisioner::NAME} v#{Provisioner::VERSION}"
              puts "#{ prefix } https://github.com/STARTcloud/#{Provisioner::NAME}/releases/tag/v#{Provisioner::VERSION}"

              puts "#{ prefix } Transferring Debugging files back to Host"
              transfer_cmd = "vagrant scp :/vagrant/support-bundle/provisioned-adapters.yml .vagrant/provisioned-adapters.yml"
              transfer_cmd = "vagrant ssh -c 'cat /vagrant/support-bundle/provisioned-adapters.yml' > .vagrant/provisioned-adapters.yml" if not Vagrant.has_plugin?("vagrant-scp-sync")
              system(transfer_cmd)

              ansible_log = "vagrant scp :/home/#{host['settings']['vagrant_user']}/ansible.log #{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}-ansible.log"
              system(ansible_log) if Vagrant.has_plugin?("vagrant-scp-sync")

              support_bundle = "vagrant scp :/vagrant/support-bundle.zip support-bundle.zip"
              system(support_bundle) if Vagrant.has_plugin?("vagrant-scp-sync")

              if File.exist?('.vagrant/provisioned-adapters.yml')
                adapters_content = File.read('.vagrant/provisioned-adapters.yml')
                begin
                  adapters = YAML.load(adapters_content)
                rescue Psych::SyntaxError => e
                  puts "YAML Syntax Error: #{e.message}"
                  adapters = nil
                end

                if adapters && adapters.is_a?(Hash) && adapters.key?('adapters')
                  public_adapter = adapters['adapters'].find { |adapter| adapter['name'] == 'public_adapter' }
                  nat_adapter = adapters['adapters'].find { |adapter| adapter['name'] == 'nat_adapter' }

                  ip_address = public_adapter&.fetch('ip') || nat_adapter&.fetch('ip')

                  open_url = "https://#{ip_address.split('/').first}:443/welcome.html"

                  adapters['adapters'].each do |adapter_hash|
                    adapter_hash.transform_keys!(&:to_s)
                  end

                  output_data = {
                    'open_url' => open_url,
                    'adapters' => adapters['adapters']
                  }
                  puts "#{ prefix } Network Information Can be found here: "
                  puts "#{ prefix }     #{File.join(Dir.pwd, 'results.yml')}"
                  Hosts.write_results_file(output_data, 'results.yml', true)
                  puts "#{ prefix } You can access the Welcome Page Here: "
                  puts "#{ prefix }     #{ open_url }"
                  system("echo '" + open_url + "' > .vagrant/done.txt")

                  ## For CI/CD Automation Purposes Only
                  if host['settings']['debug_build']
                    puts "#{ prefix } Transferring Hosts Template back to Host"
                    id_transfer_cmd = "vagrant ssh -c 'cat /vagrant/ansible/auto-SHI-Hosts.yml' > ./templates/auto-SHI-Hosts.yml"
                    id_transfer_cmd = "vagrant scp :/vagrant/ansible/auto-SHI-Hosts.yml ./templates/auto-SHI-Hosts.yml" if Vagrant.has_plugin?("vagrant-scp-sync")
                    system(id_transfer_cmd)
                  end

                  ## Copy the Updated Key from the VM, and then Delete the default Template Key from the VM
                  if host['settings']['vagrant_ssh_insert_key']
                    puts "#{ prefix } Transferring New SSH key"
                    id_transfer_cmd = "vagrant ssh -c 'cat /home/startcloud/.ssh/id_ssh_rsa' > #{host['settings']['vagrant_user_private_key_path']}"
                    id_transfer_cmd = "vagrant scp :/home/startcloud/.ssh/id_ssh_rsa #{host['settings']['vagrant_user_private_key_path']}" if Vagrant.has_plugin?("vagrant-scp-sync")
                    system(id_transfer_cmd)
                    system(%x(vagrant ssh -c "sed -i '/vagrantup/d' /home/startcloud/.ssh/id_ssh_rsa"))
                  end
                end
              else
                puts "Error: .vagrant/provisioned-adapters.yml file does not exist."
              end
            end
          end
        end
      end

      if host['zones'] && host['zones'].has_key?('post_provision_boot') && host['zones']['post_provision_boot'] && host['settings']['provider_type'] == 'zones'
        config.trigger.after [:up, :provision] do |trigger|
          trigger.info = "post_provision_boot is true, Waiting for instance to stop"
          trigger.ruby do |env, machine|
            sleep 30
            loop do
              system("vagrant status #{machine.name}")
              break if %x(vagrant status #{machine.name}) =~ /stopped/
              sleep 10
            end
            post_reboot_cmd = "pfexec zoneadm -z #{machine.name} boot"
            system(post_reboot_cmd)
          end
        end
      end
    end
  end

  def self.get_bridge_interface(path_VBoxManage)
    # Gather a list of Bridged Interfaces that Virtualbox is aware of, We only want to get the ones that are a status of Up.
    vm_interfaces = %x[#{path_VBoxManage} list bridgedifs].split("\n")
    interfaces = vm_interfaces.select { |line| line.start_with?('Name') || line.start_with?('Status') }
    pairs = interfaces.each_slice(2).select { |_, status_line| status_line.include? "Up" }.map { |name_line, _| name_line.sub("Name:", '').strip }

    # This gathers the default Route so as to further narrow the list of interfaces to use, since these would likely have public access
    defroute = if Vagrant::Util::Platform.windows?
      powershell_command = [
        "Get-NetRoute -DestinationPrefix '0.0.0.0/0'",
        "Sort-Object -Property { $_.InterfaceMetric + $_.RouteMetric }",
        "Get-NetAdapter -InterfaceIndex { $_.ifIndex }",
        "foreach { $_.InterfaceDescription }"
      ].join(" | ")

      stdout, stderr, status = Open3.capture3("powershell", "-Command", powershell_command)
      stdout.strip
    else
      stdout, stderr, status = Open3.capture3("netstat -rn -f inet")
      stdout.split("\n").find { |line| line.include? "UG" }&.split("\s")
    end

    # We then compare the interfaces that are up, and then compare that with the output of the defroute
    bridge = nil
    pairs.each do |active_interface|
      if Vagrant::Util::Platform.windows?
        bridge = active_interface if !defroute.nil? && active_interface.start_with?(defroute.to_s)
      elsif Vagrant::Util::Platform.linux?
        bridge = active_interface if !defroute[7].nil? && active_interface.start_with?(defroute[7])
      elsif Vagrant::Util::Platform.darwin?
        bridge = active_interface if !defroute[3].nil? && active_interface.start_with?(defroute[3])
      end
    end

    bridge
  end

  def self.load_secrets
    secrets_dir = File.dirname(__FILE__)
    secrets_path = File.join(secrets_dir, '../secrets.yml')
    hidden_secrets_path = File.join(secrets_dir, '../.secrets.yml')
    
    secrets = {}
    
    # Load secrets.yml if it exists
    if File.file?(secrets_path)
      secrets.merge!(YAML.load(File.read(secrets_path)) || {})
    end
    
    # Load .secrets.yml if it exists, overwriting any duplicate keys
    if File.file?(hidden_secrets_path)
      secrets.merge!(YAML.load(File.read(hidden_secrets_path)) || {})
    end
    
    secrets
  end

  def self.rsync_version_low?
    return false unless Vagrant::Util::Platform.darwin?
    `rsync --version`.include?('2.6.9') || `rsync --version` < '2.6.9'
  end

  def self.delete_files(trigger, files_to_delete)
    files_to_delete.each do |file|
      if File.exist?(file)
        FileUtils.rm_f(file)
        trigger.info = "Deleted file: #{file}"
      else
        trigger.info = "File not found: #{file}"
      end
    end
  end

  def self.write_results_file(data, file_path, yaml)
    File.delete(file_path) if File.exist?(file_path)
    File.open(file_path, 'w') do |file|
      file.flock(File::LOCK_EX) # Exclusive lock
      file.write(data) if not yaml
      file.write(data.to_yaml) if yaml
      file.flock(File::LOCK_UN) # Unlock the file
    end
  end

end
