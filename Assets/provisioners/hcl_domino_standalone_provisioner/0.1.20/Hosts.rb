# coding: utf-8
require File.expand_path("#{File.dirname(__FILE__)}/version.rb")

# This class takes the Hosts.yaml and set's the neccessary variables to run provider specific sequences to boot a VM.
class Hosts
  def Hosts.configure(config, settings)

    ## Load your Secrets file
    secrets = YAML::load(File.read("#{File.dirname(__FILE__)}/.secrets.yml")) if File.exists?("#{File.dirname(__FILE__)}/.secrets.yml")

    # Main loop to configure VM
    settings['hosts'].each_with_index do |host, index|
      provider = host['provider-type']

      if host.has_key?('plugins')
        host['plugins'].each do |plugin|
          unless Vagrant.has_plugin?("#{plugin}")
            system("vagrant plugin install #{plugin}")
            exit system('vagrant', *ARGV)
          end
        end
      end
      config.vm.define "#{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}" do |server|

        #Box Settings -- Used in downloading and packaging Vagrant boxes
        server.vm.box = host['settings']['box']
        server.vm.box_version = host['settings']['box_version']
        server.vm.boot_timeout = host['settings']['setup_wait']
        # Setup SSH and Prevent TTY errors
        server.ssh.username = host['settings']['vagrant_user']
        #server.ssh.password =  host['settings']['vagrant_user_pass']
        server.ssh.private_key_path = host['settings']['vagrant_user_private_key_path']
        server.ssh.insert_key = host['settings']['vagrant_insert_key']
        server.ssh.forward_agent = host['settings']['ssh_forward_agent']
        config.vm.communicator = :ssh
        config.winrm.username = host['settings']['vagrant_user']
        config.winrm.password = host['settings']['vagrant_user_pass']
        config.winrm.timeout = host['settings']['setup_wait']
        config.winrm.retry_delay = 30
        config.winrm.retry_limit = 1000

        ## Networking
        ## Note Do not place two IPs in the same subnet on both nics at the same time, They must be different subnets or on a different network segment(ie VLAN, physical seperation for Linux VMs)
        if host.has_key?('networks') and !host['networks'].empty?
          host['networks'].each_with_index do |network, netindex|
              network['vmac'] = network['mac'].tr(':', '') if host['provider-type'] == 'virtualbox'
              ## Use default route as the Gateway device
              bridge = network['bridge'] if defined?(network_bridge)

              vm_interfaces = %x[VBoxManage list bridgedifs].split("\n")
              interfaces = []
              vm_interfaces.each do |line|
                  interfaces.append(line) if line.start_with?('Name')
                  interfaces.append(line) if line.start_with?('Status')
              end

              pair = ""
              pairs = []
              interfaces.each_with_index do |line, index|
                  pair = line if index %2 ==0 and line.start_with?("Name:")
                  pairs.append(pair.sub("Name:", '').strip) if index %2 !=0 and line.include? "Up"
                  pair = "" if index %2 !=0
              end

              defroute = ""
              if not Vagrant::Util::Platform.windows?
                %x[netstat -rn -f inet].split("\n").each do |line|
                    defroute = line.split("\s") if line.include? "UG"
                end
              else
                defroute = %x[powershell "Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object -Property { $_.InterfaceMetric + $_.RouteMetric } | Get-NetAdapter  -InterfaceIndex  { $_.ifIndex } |  foreach { $_.InterfaceDescription }"]
              end

              pairs.each_with_index do |active_interface, index|
                bridge = active_interface if !defroute.nil? and active_interface.start_with?(defroute.to_s) and Vagrant::Util::Platform.windows? and !defined?(network_bridge)
                bridge = active_interface if !defroute[7].nil? and active_interface.start_with?(defroute[7]) and Vagrant::Util::Platform.linux? and !defined?(network_bridge)
                bridge = active_interface if !defroute[3].nil? and active_interface.start_with?(defroute[3]) and Vagrant::Util::Platform.darwin? and !defined?(network_bridge)
              end

              if network['type'] == 'external'
                server.vm.network "public_network",
                  ip: network['address'],
                  dhcp: network['dhcp4'],
                  dhcp6: network['dhcp6'],
                  bridge: bridge,
                  auto_config: network['autoconf'],
                  netmask: network['netmask'],
                  vmac: network['mac'],
                  mac: network['vmac'],
                  gateway: network['gateway'],
                  nictype: network['type'],
                  nic_number: netindex,
                  managed: network['is_control'],
                  vlan: network['vlan']
              end
              if network['type'] == 'host'
                server.vm.network "private_network",
                  ip: network['address'],
                  netmask: network['netmask']
              end
          end
        end

        ##### Disk Configurations #####
        ## https://sleeplessbeastie.eu/2021/05/10/how-to-define-multiple-disks-inside-vagrant-using-virtualbox-provider/
        disks_directory = File.join("./", "disks")
        
        ## Create Disks
        config.trigger.before :up do |trigger|
          if host.has_key?('disks') and !host['disks'].empty?
            trigger.name = "Create disks"
            trigger.ruby do
              unless File.directory?(disks_directory)
                FileUtils.mkdir_p(disks_directory)
              end
              
              host['disks']['additional_disks'].each_with_index do |disks, diskindex|
                local_disk_filename = File.join(disks_directory, "#{disks['volume_name']}.vdi")
                unless File.exist?(local_disk_filename)
                  puts "Creating \"#{disks['volume_name']}\" disk with size \"#{disks['size'].delete('^0-9').to_i * 1024}\""
                  system("VBoxManage createmedium --filename #{local_disk_filename} --size #{disks['size'].delete('^0-9').to_i * 1024} --format VDI")
                end
              end
            end  
          end
        end

        # create storage controller on first run
        if host.has_key?('disks') and !host['disks'].empty?
          unless File.directory?(disks_directory)
            config.vm.provider "virtualbox" do |storage_provider|
              storage_provider.customize ["storagectl", :id, "--name", "Virtual I/O Device SCSI controller", "--add", "virtio-scsi", '--hostiocache', 'off']
            end
          end
        end

        # attach storage devices
        if host.has_key?('disks') and !host['disks'].empty?
          config.vm.provider "virtualbox" do |storage_provider|
            host['disks']['additional_disks'].each_with_index do |disks, diskindex|
              local_disk_filename = File.join(disks_directory, "#{disks['volume_name']}.vdi")
              unless File.exist?(local_disk_filename)
                storage_provider.customize ['storageattach', :id, '--storagectl', "Virtual I/O Device SCSI controller", '--port', disks['port'], '--device', 0, '--type', 'hdd', '--medium', local_disk_filename]
              end
            end
          end
        end

        # cleanup after "destroy" action
        config.trigger.after :destroy do |trigger|
          if host.has_key?('disks') and !host['disks'].empty?
            trigger.name = "Cleanup operation"
            trigger.ruby do
              # the following loop is now obsolete as these files will be removed automatically as machine dependency
              host['disks']['additional_disks'].each_with_index do |disks, diskindex|
                local_disk_filename = File.join(disks_directory, "#{disks['volume_name']}.vdi")
                if File.exist?(local_disk_filename)
                  puts "Deleting \"#{disks['volume_name']}\" disk"
                  system("vboxmanage closemedium disk #{local_disk_filename} --delete")
                end
              end
              if File.exist?(disks_directory)
                FileUtils.rmdir(disks_directory)
              end
            end
          end
        end

        ##### Begin Virtualbox Configurations #####
        server.vm.provider :virtualbox do |vb|
          if host['settings']['memory'] =~ /gb|g|/
            host['settings']['memory']= 1024 * host['settings']['memory'].tr('^0-9', '').to_i
          elsif host['settings']['memory'] =~ /mb|m|/
            host['settings']['memory']= host['settings']['memory'].tr('^0-9', '')
          end
          vb.name = "#{host['settings']['server_id']}--#{host['settings']['hostname']}.#{host['settings']['domain']}"
          vb.customize ['modifyvm', :id, '--ostype', host['settings']['os_type']]
          vb.customize ["modifyvm", :id, "--vrdeport", host['settings']['consoleport']]
          vb.customize ["modifyvm", :id, "--vrdeaddress", host['settings']['consolehost']]
          vb.customize ["modifyvm", :id, "--cpus", host['settings']['vcpus']]
          vb.customize ["modifyvm", :id, "--memory", host['settings']['memory']]
          vb.customize ["modifyvm", :id, "--firmware", 'efi'] if host['settings']['firmware_type'] == 'UEFI'
          vb.customize ['modifyvm', :id, "--vrde", 'on']
          vb.customize ['modifyvm', :id, "--natdnsproxy1", 'off']
          vb.customize ['modifyvm', :id, "--natdnshostresolver1", 'off']
          vb.customize ['modifyvm', :id, "--accelerate3d", 'off']
          vb.customize ['modifyvm', :id, "--vram", '256']

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

        # Register shared folders
        if host.has_key?('folders')
					host['folders'].each do |folder|
						mount_opts = folder['type'] == folder['type'] ? ['actimeo=1'] : []
						server.vm.synced_folder folder['map'], folder ['to'],
						type: folder['type'],
						owner: folder['owner'] ||= host['settings']['vagrant_user'],
						group: folder['group'] ||= host['settings']['vagrant_user'],
						mount_options: mount_opts,
						automount: true,
            rsync__args: folder['args'] ||= ["--verbose", "--archive", "-z", "--copy-links"],
						rsync__chown: folder['chown'] ||= 'false',
            create: folder['create'] ||= 'false',
						rsync__rsync_ownership: folder['rsync_ownership'] ||= 'true',
						disabled: folder['disabled']||= false
					end
				end

        # Add Branch Files to Vagrant Share on VM Change to Git folders to pull
        scriptsPath = File.dirname(__FILE__) + '/scripts'
        if host['provisioning'].has_key?('role') && host['provisioning']['role']['enabled']
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
          host['provisioning']['ansible']['scripts'].each do |scripts|
            if scripts.has_key?('local')
              scripts['local'].each do |localscript|
                server.vm.provision :ansible_local do |ansible|
                  ansible.playbook = localscript['script']
                  ansible.compatibility_mode = localscript['compatibility_mode'].to_s
                  ansible.install_mode = "pip" if localscript['install_mode'] == "pip"
                  ansible.verbose = localscript['verbose']
                  ansible.config_file = "/vagrant/ansible/ansible.cfg"
                  ansible.extra_vars = {
                    settings: host['settings'],
                    networks: host['networks'],
                    secrets: secrets,
                    role_vars: host['vars'],
                    provision_roles: host['roles'],
                    demo_tasks_version: DemoTasks::VERSION,
                    ansible_winrm_server_cert_validation: "ignore",
                    ansible_ssh_pipelining:localscript['ssh_pipelining'],
                    ansible_python_interpreter:localscript['ansible_python_interpreter']}
                end
              end
            end

            ## If Ansible is available on the host or is not installed in the template you are spinning up, use 'ansible'
            if scripts.has_key?('remote')
              scripts['remote'].each do |remotescript|
                server.vm.provision :ansible do |ansible|
                  ansible.playbook = remotescript['script']
                  ansible.compatibility_mode = remotescript['compatibility_mode'].to_s
                  ansible.verbose = remotescript['verbose']
                  ansible.extra_vars = {
                    settings: host['settings'],
                    networks: host['networks'],
                    secrets: secrets,
                    role_vars: host['vars'],
                    provision_roles: host['roles'],
                    demo_tasks_version: DemoTasks::VERSION,
                    ansible_winrm_server_cert_validation: "ignore",
                    ansible_ssh_pipelining:remotescript['ssh_pipelining'],
                    ansible_python_interpreter:remotescript['ansible_python_interpreter']
                  }
                end
              end
            end
          end
        end

        # Run the Docker-Compose provisioners defined in hosts.yml
        if host['provisioning'].has_key?('docker') && host['provisioning']['docker']['enabled']
          host['provisioning']['docker']['docker_compose'].each do |file|
              server.vm.provision 'docker'
              server.vm.provision :docker_compose, yml: file, run: "always"
          end
        end
      end

      ## Open the browser after provisioning
      if host.has_key?('networks') && host['settings']['provider-type'] == 'virtualbox'
        host['networks'].each_with_index do |network, netindex|
          config.trigger.after [:up] do |trigger|
            trigger.ruby do |env,machine|
              puts "This server has been provisioned with DemoTasks Roles v" + DemoTasks::VERSION
              puts "https://github.com/DominoVagrant/demo-tasks/releases/tag/v" + DemoTasks::VERSION
              ipaddress = network['address']
              system("vagrant ssh -c 'cat /vagrant/completed/ipaddress.yml' > .vagrant/provisioned-briged-ip.txt")
              ipaddress = File.readlines(".vagrant/provisioned-briged-ip.txt").join("") if network['dhcp4']
              open_url = "https://" + ipaddress + ":443/welcome.html"
              system("echo '" + open_url + "' > .vagrant/done.txt")
            end
          end
        end
      end
    end
  end
end
