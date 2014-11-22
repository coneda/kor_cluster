#!/bin/bash -e

function setup_docker {
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
  sh -c "echo deb https://get.docker.com/ubuntu docker main > /etc/apt/sources.list.d/docker.list"

  apt-get update
  apt-get upgrade -y
  apt-get install lxc-docker pwgen
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
