<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/DominoVagrant/demo-v2-task-based/">
    <img src="https://startcloud.com/assets/logo-big.jpg" alt="Logo" width="200" height="100">
  </a>

  <h3 align="center">Domino Vagrant Build</h3>

  <p align="center">
    An README to jumpstart your build of the Domino Development
    <br />
    <a href="https://github.com/DominoVagrant/demo-v2-task-based/"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/DominoVagrant/demo-v2-task-based/">View Demo</a>
    ·
    <a href="https://github.com/DominoVagrant/demo-v2-task-based/issues">Report Bug</a>
    ·
    <a href="https://github.com/DominoVagrant/demo-v2-task-based/issues">Request Feature</a>
  </p>
</p>

<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About the Project](#dominovagrant)
  * [Built With](#built-with)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
    * [Mac OS X](https://github.com/DominoVagrant/demo-v2-task-based/blob/master/MacMojaveReadme.md) -- Quick Start
    * [Windows](https://github.com/DominoVagrant/demo-v2-task-based/blob/master/Win10ReadMe.md) -- Quick Start
* [Deployment](#deployment)
  * [Cloning](#cloning-the-repo-locally)
  * [Overview](#configuring-the-environment)
  * [Variables](#commonly-changed-parameters)
  * [Source Files](#source-files)
* [Initialization](#starting-the-vm)
  * [Access Methods](#accessing-the-domino-server)
    * [Web](#web-interface)
    * [Notes Client](#access-from-notes-client)
    * [Console](#domino-console)
* [Common Issues](#common-problems)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#authors)
* [Acknowledgements](#acknowledgments)


## DominoVagrant
Primary goal is to use Vagrant to deploy the latest Domino Server in an Linux VM. Vagrant and Role Specific Variables will be passed along, automating installation via the RestAPI interace and Mooneshine or other tools that support CRUD API calls. This uses a Specialized Packer Build that cuts down deployment time:

* **Template:** [Packer](https://app.vagrantup.com/STARTcloud/boxes/debian11-server)
* **Build Source:** [Repo](Notyetavailableforpublicconsumption)

Each Release will be a at the time, stable branch. Recommended to use the latest.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes, as well as what will power the build process of the VMs at Prominic.NET.

### Prerequisites

You will need some software on your PC or Mac:

```
git
Vagrant
Virtualbox
```

## Installation

To ease deployment, we have a few handy scripts that will utlize a package manager for each OS to get the pre-requisite software for your host OS. This is NOT required, this is to help you ensure you have all the applications that are neccessary to run this VM.

#### Windows
Powershell has a package manager named Chocalatey which is very similar to SNAP, YUM, or other Package manager, We will utilize that to quickly install Virtualbox, Vagrant and Git.

Powershell
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install vagrant
choco install virtualbox
choco install git.install
```

For those that need to run this in a Command Prompt, you can use this:

CMD
```bat
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
choco install vagrant
choco install virtualbox
choco install git.install
```

#### Mac
Just like Windows and other Linux repos, there is a similar package manager for Mac OS X, Homebrew, We will utilize that to install the prequsites. You will likley need to allow unauthenticated applications in the Mac OS X Security Settings, there are reports that Mac OS X Mojave will require some additional work to get running correctly. You do NOT have to use these scripts to get the pre-requisites on your Mac, it is recommened, you simply need to make sure you have the 3 applications installed on your Mac.

```shell
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew cask install virtualbox
brew cask install vagrant
brew cask install vagrant-manager
brew install git
```

#### CentOS 7
We will utilize YUM and a few other bash commands to get the Virtualbox, Git,  and Vagrant installed.

YUM
```shell
yum -y install gcc dkms make qt libgomp patch kernel-headers kernel-devel binutils glibc-headers glibc-devel font-forge
cd /etc/yum.repo.d/
wget http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo
yum install -y VirtualBox-5.1
/sbin/rcvboxdrv setup
yum -y install https://releases.hashicorp.com/vagrant/1.9.6/vagrant_1.9.6_x86_64.rpm
sudo yum install git
```

#### Ubuntu
We will utilize APT to get the Virtualbox, Git,  and Vagrant installed.

APT
```shell
sudo apt-get install virtualbox vagrant git-core -y
```

## Deployment
### Cloning the repo locally

Open up a terminal and perform the following git command in order to save the Project to a local folder:

```shell
git clone https://github.com/DominoVagrant/demo-v2-task-based
```

### Configuring the Environment
Once you have navigated into the projects directory. You will need to modify the Hosts.yml to your specific Environment.

Please set the configuration file with the correct, Network and Memory and CPU settings your host machine will allow, as these may vary from system to system, I cannot predict your Machines CPU and Network Requirements. You will need to make sure that you do not over allocate CPU, and RAM.

##### Networking is setup to create one NAT adapter for Vagrant communications and one Bridged Adapter.
The bridge adapter needs to be specified or it will prompt upon deployment.
Setting dhcp4 to true (ipv6 not yet fully supported try at your own risk) will pull a IP from your local network's DHCP server.

##### Secrets

If you have any sensitive credentials, You will also need to create ```.secrets.yml``` in the root of the project. This is where you can store credentials variables that may contain sensitive data. this will prevent you from uploading them to the repo should you contribute back. Please note that if you remove this from the .gitignore you risk uploading sensitve data.

```
cd demo-v2-task-based
touch .secrets.yml
nano Hosts.yml
```

## Commonly Changed Parameters:

* ip: Use any IP on your Internal Network that is NOT in use by any other machine.
* gateway: This is the IP of your Router
* dhcp4: true/false
* hostname: This is the Hostname of the VM,
* domain: This is the domain to complete the FQDN
* mac: This is your machines Network unique identifier, if you run more than one instance on a network, randonmize this. [Mac Generator](https://www.miniwebtool.com/mac-address-generator/)
* netmask: Set this to the subnet you have your network configured to. This is normally: 255.255.255.0
* name: The Vagrant unique identifier
* cpu: The number of cores you are allocating to this machine. Please beware and do not over allocate. Overallocation may cause instability
* memory: The amount of Memory you are allocating to the machine.  Please beware and do not over allocate. Overallocation may cause instability



### Modifying Roles
The default provisioning engine is ansible-local. This allows us to template our variables into files before deploying and executing the installers.
This allows us to set dynamic usernames, paths, passwords, etc.

#### Domino One-Touch References
In order to make changes to the one touch installer. Modify the template file setup.json.j2 in the /templates folder of the role "domino-config".

You can find more information on the fields and how they correspond to Field Values in Doimino designer here:

[Domino-OneTouch](https://help.hcltechsw.com/domino/12.0.0/admin/inst_usingthedominoserversetupprogram_c.html)

## Source Files

If you have Domino and the installations files in a remote repository.
You can define them in the Hosts.yml under their respective variables.

If you do not have a repository to pull your installation files from.
You can place the archived installers in the ./installers/{{APPLICATION}}/archived directory.
These will be expanded into their respective folders under /vagrant/installers/{{APPLICATION}}/archived.

You will need to supply the Domino installer and optional fix pack files
yourself (eg, Domino_12.0_Linux_English.tar, Domino_1101FP2_Linux.tar).

## Cross Certifying

If you want to access the server from a Notes ID, create a safe ID using the instructions [here](#access-from-notes-client)

**Place your file into the ./safe-id-to-cross-certify folder.**

## Starting the VM
The installation process is estimated to take about 15 - 30 Minutes.

```
vagrant up
```

At this point, you can execute 'vagrant up' in the git checkout directory
to spin up a vm instance, or use the utility scripts
./scripts/vagrant_up.sh, ./scripts/vagrant_up.ps1 to create a log file with the initialization
output in addition to showing on the screen.

Once the system has been provisioned, you can use 'vagrant ssh' to access
it, or again the utility scripts vagrant_ssh.sh/vagrant_ssh.ps1 to create
a log file of the ssh session.

View the contents of the CommandHelp.text for more details.
This file will also be displayed followed each vagrant up operation for
your continued reference.

## Accessing the Domino Server

The Domino server will be started automatically when `vagrant up` completes.

### Domino Console

To access the console, run:

```vagrant ssh -c "screen -r"```
or
```vagrant ssh -c "sudo domino console"```

### Web Interface

The web interface of the server is here: https://yourstaticordhcpip:443/downloads/welcome.html

### Access from Notes Client

If you want to access the server from a Notes Client, you will need to cross-certify your ID.  To do this, first create a safe ID:
1. Open User Security:
	- MacOS: HCL Notes > Security > User Security
	- Windows: File > Security > User Security
2. Select the Your Identity > Your Certificates tab
3. Run Other Actions > Export NotesID Safe ID.  Do not set a password

Copy this ID to `./safe-id-to-cross-certify` and update `safe_notes_id`, and run `vagrant up`.

Then you will need to create a connection document in your local Notes client.
1. File > Open > HCL Notes Application
2. Open names.nsf on your local machine
3. Click `Advanced` in the bottom of the left sidebar
4. Open the Connections view
5. Click New > Server Connection
	1. In the Basic tab, set `Server name` as "demo/Demo" and check the `TCP/IP` checkbox
	2. In the Advanced tab, set the `Destination server address` to "127.0.0.1:1352"
	3. Click `Save & Close`

Then you can open a database on the server like this:
1. File > Open > HCL Notes Application
2. Enter "demo/DEMO" as the server name
3. Select a database (like names.nsf) and click Open

### Domino Default Credentials

* username: Demo Admin
* password: password

## Common Problems

### Error for Headless VirtualBox

If you get an error indicating that VirtualBox could not start in headless mode, open Vagrantfile and uncomment this line

```
     #vb.gui = true
```

## Roadmap

See the [open issues](https://github.com/DominoVagrant/demo-v2-task-based/issues) for a list of proposed features (and known issues).

## Built With
* [Vagrant](https://www.vagrantup.com/) - Portable Development Environment Suite.
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads) - Hypervisor.
* [Ansible](https://www.ansible.com/) - Virtual Manchine Automation Management.

## Contributing

Please read [CONTRIBUTING.md](https://www.prominic.net) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors
* **Joel Anderson** - *Initial work* - [JoelProminic](https://github.com/JoelProminic)
* **Justin Hill** - *Initial work* - [JustinProminic](https://github.com/JustinProminic)
* **Mark Gilbert** - *Refactor* - [MarkProminic](https://github.com/MarkProminic)

See also the list of [contributors](https://github.com/DominoVagrant/demo-v2-task-based/graphs/contributors) who participated in this project.

## License

This project is licensed under the SSLP v3 License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone whose code was used
