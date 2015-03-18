# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "kor_cluster", :primary => true do |kor|
    kor.vm.box = "coneda/ubuntu14:04"
    kor.vm.box_url = "http://download.coneda.net/coneda_ubuntu14.04.box"

    kor.vm.provision :shell, path: "vagrant.sh", args: "setup_docker"

    kor.vm.network :forwarded_port, host: 8080, guest: 8001

    kor.vm.provider "virtualbox" do |vbox|
      vbox.name = "kor_cluster"
      vbox.customize ["modifyvm", :id, "--memory", "2048"]
    end
  end

end
