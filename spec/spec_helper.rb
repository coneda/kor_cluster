ROOT = File.expand_path(File.dirname(__FILE__) + '/..')
CLUSTER_SCRIPT_ROOT = "/vagrant"
CLUSTER_ROOT = "/opt/test_cluster"

Bundler.setup
Bundler.require

module Helpers

  def output
    File.read "#{ROOT}/tmp/output.txt"
  end

  def status
    @status
  end

  def vagrant_up
    system "vagrant up"
  end

  def vagrant_destroy
    system "vagrant destroy -f"
  end

  def vagrant_read_file(filename)
    `vagrant ssh -c "cat #{filename}"`
  end

  def vagrant(command, options = {})
    if File.exists?("#{ROOT}/tmp/output.txt")
      system "rm #{ROOT}/tmp/output.txt"
    end

    options = {
      :verbose => false
    }.merge(options)

    command = "vagrant ssh -c \"#{command}\" >> #{ROOT}/tmp/output.txt 2>> #{ROOT}/tmp/output.txt"
    result = system command
    @status = $?.exitstatus
    if options[:verbose]
      puts [
        "--- BEGIN VAGRANT COMMAND (status: #{status.inspect}) ---",
        command,
        "--- OUTPUT ---",
        output,
        "--- END VAGRANT COMMAND ---"
      ].join("\n")
    end
    result
  end

end

RSpec.configure do |config|
  config.include Helpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before :all do
    vagrant_destroy
    vagrant_up
  end

  config.before :each do
    vagrant "sudo /vagrant/vagrant.sh clean_docker"
    vagrant "sudo rm -rf #{CLUSTER_ROOT}"
    vagrant "sudo mkdir -p #{CLUSTER_ROOT}"
  end

  config.after :each do
    system "rm #{ROOT}/tmp/output.txt"
  end

end
