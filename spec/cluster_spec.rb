require 'spec_helper'

describe "cluster.sh" do

  it "should make sure the ssmtp config was changed before booting" do
    run "sudo #{CLUSTER_SCRIPT_ROOT}/cluster.sh create #{CLUSTER_ROOT} test_cluster"
    expect(run "sudo #{CLUSTER_ROOT}/cluster.sh boot").not_to succeed

    run "sudo cp /vagrant/spec/fixtures/ssmtp.conf #{CLUSTER_ROOT}/ssmtp/ssmtp.conf"
    expect(run "sudo #{CLUSTER_ROOT}/cluster.sh boot").to succeed
  end

  context "with a configured cluster" do

    before :each do
      run "sudo #{CLUSTER_SCRIPT_ROOT}/cluster.sh create #{CLUSTER_ROOT} test_cluster"
      run "sudo cp /vagrant/spec/fixtures/ssmtp.conf #{CLUSTER_ROOT}/ssmtp/ssmtp.conf"
    end

    it "should create a cluster scaffold" do
      expect(File.exists? "#{CLUSTER_ROOT}/cluster.sh").to be_truthy
      expect(File.exists? "#{CLUSTER_ROOT}/config.sh").to be_truthy
      expect(File.exists? "#{CLUSTER_ROOT}/mysql.cnf").to be_truthy
    end

    it "should create a cluster scaffold without a name" do
      run "sudo #{CLUSTER_SCRIPT_ROOT}/cluster.sh create #{CLUSTER_ROOT}/another_cluster"

      config_data = File.read "#{CLUSTER_ROOT}/another_cluster/config.sh"
      cluster_name = config_data.scan(/^CLUSTER_NAME=.*$/).first.split("=").last
      expect(cluster_name).not_to eq("")
    end

    it "should boot" do
      run "sudo #{CLUSTER_ROOT}/cluster.sh boot"

      expect(run "sudo docker ps | grep test_cluster_mysql").to succeed
      expect(run "sudo docker ps | grep test_cluster_elastic").to succeed
    end

    it "should shutdown without leaving any containers behind" do
      run "sudo #{CLUSTER_ROOT}/cluster.sh boot"
      run "sudo #{CLUSTER_ROOT}/cluster.sh shutdown"
      result = run "sudo docker ps -a -q | wc -l"
      expect(result[:out].strip.to_i).to eq(0)
    end

    it "should create an instance" do
      run "sudo #{CLUSTER_ROOT}/cluster.sh boot"
      
      # Waiting 10 seconds so that the cluster can fully boot
      sleep 10

      run "sudo VERSION=v1.8 PORT=80 #{CLUSTER_ROOT}/cluster.sh new ti"
      expect(File.exists? "#{CLUSTER_ROOT}/instances/ti/instance.sh").to be_truthy
    end

    it "should restart the containers when the docker daemon is restarted" do
      run "sudo #{CLUSTER_ROOT}/cluster.sh boot"
      run 'sudo service docker restart'

      result = run 'sudo docker ps -q'
      expect(result[:out].split("\n").size).to eq(2)
    end
    
  end

end