# KorCluster

In order to diminish the overhead when setting up ConedaKOR, we believe Docker
can help by providing preconfigured images containing all dependencies for the
app.

KorCluster is basically a simple shell script that allows to instantiate several
clusters per host and several ConedaKOR instances per cluster. All instances
within a cluster share a mysql and an elastic instance. Each instance will be
available on a distinct port and brings a web process as well as a background
process to perform various tasks (mostly image processing).

To combine the services and potentially use a joint SSL certificate, a nginx
server is also part of a cluster. Its configuration is based on existing
instances and their setup.

## Requirements

* docker
* pwgen

## Running tests

To run the tests, you can bring up the test host with vagrant (this takes a few
minutes on most machines)

    vagrant up

and then run the tests (the first time you run this, the docker daemon will
download the sample ConedaKOR containers which might also take a while):

    vagrant ssh -c "cd /vagrant && bundle exec rspec"

... which should just output green stuff :)

## Usage

The script features several commands which all operate either on the cluster or
on a singular instance. This scope is defined by where the script was called.
That is possible because the cluster script symlinks itself to the instance's
directory when it creates it.

### Clusters

first, clone the repository:

    git clone https://github.com/coneda/kor_cluster.git kor_cluster
    cd kor_cluster

Then create a cluster:

    CLUSTER_PORT=443 ./cluster.sh create /var/my_kor_cluster

That will bootstrap a cluster and it will also symlink the cluster.sh script to
the cluster root at /var/my_kor_cluster/cluster.sh

There is some basic configuration that has to be changed according to your
setup:

* make sure to change ssmtp.conf to a working email configuration
* change nginx.conf according to your needs

The CLUSTER_PORT is the port on which nginx is going to listen and where all 
instances are going to be reachable. Also, a cluster can be up and down. If it
is up, mysql and elasticsearch are started. In down state, fire the following
command to bring it up:

    /var/my_kor_cluster/cluster.sh boot
    # to bring it back down again, use 'shutdown'

The proxy has to be started and stopped separately since it depends on the 
instances: When it is started, it parses the instance setup and includes vhosts
for every instance:

    /var/my_kor_cluster/cluster.sh start_proxy

and to stop it again:

    /var/my_kor_cluster/cluster.sh stop_proxy

### Instances

New instances can only be created on cluster that is up. This is because the
database for that instance has to be prepared which requires a running database
server. Also to create instances, you have to specify more information such as
the port it is going to run on. This is done with environment variables:

    VERSION=v1.9
    PORT=8001
    SERVER_NAME=my_instance.example.com
    /var/my_kor_cluster/cluster.sh new my_instance

The instance will be created in /var/my_kor_cluster/instances/my_instance and
again the cluster.sh script is symlinked. The directory also contains all
configuration and data for that instance. It can be started like this:

    /var/my_kor_cluster/instances/instance.sh start
    # again, use 'stop' to stop it


#### Upgrades

Upgrading the cluster script can simply be done by pulling this git repository.

Since the setup is based on Docker, instance upgrades are as simple as possible.
Basically the old container is stopped and the new one is fired up. In between,
sometimes the database schema needs to be altered or the layout of stored files.
Given an instance is on version `1.9.1`, upgrading it to `1.9.2` would be done
like this:

    /var/my_kor_cluster/instances/instance.sh upgrade v1.9.2

#### Snapshots

Snapshots contain the entire instance configuration as well as all of its data.
Creating a snapshot doesn't require any parameters and creates a file at
/var/my_kor_cluster/snapshots. The instance will not be available during the
(potentially lengthy) process.

The counterpart is the `import` command: It uses a previously created snapshot
to reinstate that state within an instance, for example: 

    cd /var/my_kor_cluster/instances/my_instance
    ./instance.sh import ../../snapshots/some_snapshot.tar.gz
