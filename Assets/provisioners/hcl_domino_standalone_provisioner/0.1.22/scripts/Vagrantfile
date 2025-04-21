## Vagrant File tooling compatabile with Bhyve and Virtualbox, potentially ESXI/Vmware,KVM
require 'yaml'
require File.expand_path("#{File.dirname(__FILE__)}/core/Hosts.rb")

settings = YAML::load(File.read("#{File.dirname(__FILE__)}/Hosts.yml"))

Vagrant.configure("2") do |config|
        Hosts.configure(config, settings)
end
