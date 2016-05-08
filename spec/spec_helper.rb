ROOT = File.expand_path(File.dirname(__FILE__) + '/..')

CLUSTER_SCRIPT_ROOT = "/vagrant"
CLUSTER_ROOT = "/tmp/test_cluster"

Bundler.setup
Bundler.require

RSpec::Matchers.define :succeed do |expected|
  match do |actual|
    if actual.is_a?(Hash) && actual[:status].is_a?(Process::Status)
      actual[:status].exitstatus == 0
    end
  end
end

RSpec.configure do |config|

  def run(command)
    rerr, werr = IO.pipe
    rout, wout = IO.pipe
    pid = Process.spawn(command, err: werr, out: wout)
    Process.wait(pid)
    werr.close
    wout.close
    {out: rout.read, err: rerr.read, status: $?}
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before :each do
    run "sudo /vagrant/vagrant.sh clean_docker"
    run "sudo rm -rf #{CLUSTER_ROOT}"
    run "sudo mkdir -p #{CLUSTER_ROOT}"
  end

end
