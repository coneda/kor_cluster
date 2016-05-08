#!/bin/bash -e

# function setup_docker {
#   apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#   sh -c "echo 'deb https://apt.dockerproject.org/repo ubuntu-trusty main' > /etc/apt/sources.list.d/docker.list"

#   apt-get update
#   apt-get upgrade -y
#   apt-get install -y linux-image-extra docker-engine pwgen
# }

function ensure_dependencies {
  apt-get install -y pwgen
  
  cd /vagrant
  bundle install
}

function ensure_rbenv {
  apt-get install -y autoconf bison build-essential libssl-dev \
    libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev \
    libffi-dev libgdbm3 libgdbm-dev git-core

  if [ ! -d /opt/rbenv ] ; then
    git clone https://github.com/sstephenson/rbenv.git /opt/rbenv
    git clone https://github.com/rbenv/ruby-build.git /opt/rbenv/plugins/ruby-build

    echo 'export RBENV_ROOT="/opt/rbenv"' >> /etc/profile.d/rbenv.sh
    echo 'export PATH="/opt/rbenv/bin:$PATH"' >> /etc/profile.d/rbenv.sh
    echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh
  fi

  source /etc/profile.d/rbenv.sh

  RUBY_VERSION=`cat /vagrant/.ruby-version`

  if [ ! -d /opt/rbenv/versions/$RUBY_VERSION ] ; then
    rbenv install $RUBY_VERSION
  fi

  rbenv shell $RUBY_VERSION
  gem install bundler
  gem update bundler

  chown -R vagrant. /opt/rbenv
  chmod -R g+w /opt/rbenv/shims
}

function clean_docker {
  for CONTAINER in `docker ps -a -q` ; do
    docker stop $CONTAINER
    docker rm $CONTAINER
  done

  # for IMAGE in `docker images -q` ; do
  #   docker rmi $IMAGE
  # done
}

$1
