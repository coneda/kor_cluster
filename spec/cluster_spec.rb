require 'spec_helper'

describe "cluster.sh" do

  before :each do
    vagrant "sudo #{CLUSTER_SCRIPT_ROOT}/cluster.sh create #{CLUSTER_ROOT} test_cluster"
  end

  after :each do
    # system "#{CLUSTER_SCRIPT_ROOT}/tmp/test/mycluster/cluster.sh shutdown &> /dev/null"
  end

  context "global" do
    it "should create a cluster scaffold" do
      expect(vagrant "[ -f #{CLUSTER_ROOT}/cluster.sh ]").to be_truthy
      expect(vagrant "[ -f #{CLUSTER_ROOT}/config.sh ]").to be_truthy
      expect(vagrant "[ -f #{CLUSTER_ROOT}/mysql.cnf ]").to be_truthy
    end

  end

  context "cluster" do
    it "should make sure the ssmtp config was changed before booting" do
      expect(vagrant "sudo #{CLUSTER_ROOT}/cluster.sh boot").to be_falsy
      vagrant "sudo cp /vagrant/spec/fixtures/ssmtp.conf #{CLUSTER_ROOT}/ssmtp/ssmtp.conf"
      expect(vagrant "sudo #{CLUSTER_ROOT}/cluster.sh boot").to be_truthy
    end

    it "should boot" do
      vagrant "sudo cp /vagrant/spec/fixtures/ssmtp.conf #{CLUSTER_ROOT}/ssmtp/ssmtp.conf"
      vagrant "sudo #{CLUSTER_ROOT}/cluster.sh boot"

      expect(vagrant "sudo docker ps | grep test_cluster_mysql").to be_truthy
      expect(vagrant "sudo docker ps | grep test_cluster_mongo").to be_truthy
      expect(vagrant "sudo docker ps | grep test_cluster_elastic").to be_truthy
    end

    it "should shutdown without leaving any containers behind" do
      vagrant "sudo cp /vagrant/spec/fixtures/ssmtp.conf #{CLUSTER_ROOT}/ssmtp/ssmtp.conf"
      vagrant "sudo #{CLUSTER_ROOT}/cluster.sh boot"
      vagrant "sudo #{CLUSTER_ROOT}/cluster.sh shutdown"
      vagrant "sudo docker ps -a -q | wc -l"
      expect(output.strip.to_i).to eq(0)
    end

    it "should create an instance" do
      vagrant "sudo cp /vagrant/spec/fixtures/ssmtp.conf #{CLUSTER_ROOT}/ssmtp/ssmtp.conf"
      vagrant "sudo #{CLUSTER_ROOT}/cluster.sh boot"
      sleep 10
      vagrant "sudo VERSION=v1.8 PORT=80 #{CLUSTER_ROOT}/cluster.sh new ti"
      expect(vagrant "[ -f #{CLUSTER_ROOT}/instances/ti/instance.sh ]").to be_truthy
    end
  end

end