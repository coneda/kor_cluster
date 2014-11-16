#!/bin/bash

export KEEP=5
export PORT="22"

function testing {
  export HOST="root@coneda.net"
  export DEPLOY_TO="/var/docker/kor"
  export COMMIT="master"
}

$1
