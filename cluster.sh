#!/bin/bash -e

# Local config

SCRIPT_PATH=`readlink -m $0`
CLUSTER_SCRIPT_ROOT="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
CALL_ROOT="$( cd "$( dirname "$0" )" && pwd )"

if [ -f $CALL_ROOT/config.sh ]; then
  source $CALL_ROOT/config.sh
fi


# Global config and lib

source $CLUSTER_SCRIPT_ROOT/lib.sh


# Initialize mysql, elasticsearch and mongodb

function create {
  local DIR=${1-.}
  mkdir -p $DIR
  DIR=`expand_path $DIR`

  CLUSTER_NAME=${2-`pwgen 6 1`}

  ln -sfn $CALL_ROOT/cluster.sh $DIR/cluster.sh

  mkdir -p $DIR/mysql
  mkdir -p $DIR/mongo
  mkdir -p $DIR/elastic
  mkdir -p $DIR/ssmtp

  tpl $CLUSTER_SCRIPT_ROOT/templates/ssmtp.conf $DIR/ssmtp/ssmtp.conf
  tpl $CLUSTER_SCRIPT_ROOT/templates/revaliases $DIR/ssmtp/revaliases
  
  mkdir -p $DIR/elastic/log
  mkdir -p $DIR/elastic/data
  mkdir -p $DIR/elastic/work
  mkdir -p $DIR/elastic/plugins

  DB_USERNAME=root
  DB_PASSWORD=`generate_password`
  tpl $CLUSTER_SCRIPT_ROOT/templates/service_config.sh $DIR/config.sh
  tpl $CLUSTER_SCRIPT_ROOT/templates/mysql.cnf $DIR/mysql.cnf
}


# Start mysql, elasticsearch and mongodb

function boot {
  SSMTP_TPL_CHECKSUM=`sha1sum $CLUSTER_SCRIPT_ROOT/templates/ssmtp.conf | cut -d" " -f 1`
  SSMTP_CHECKSUM=`sha1sum $CALL_ROOT/ssmtp/ssmtp.conf | cut -d" " -f 1`

  if [ "$SSMTP_TPL_CHECKSUM" = "$SSMTP_CHECKSUM" ]; then
    echo "Your SSMTP config file wasn't changed!"
    echo "Please adapt it to a working configuration before using this cluster"
    exit 1
  fi

  sudo docker run -d \
    --name ${CLUSTER_NAME}_mysql \
    --volume $CALL_ROOT/mysql:/var/lib/mysql \
    --env MYSQL_ROOT_PASSWORD=$DB_PASSWORD \
    mysql

  sudo docker run -d \
    --name ${CLUSTER_NAME}_mongo \
    --volume $CALL_ROOT/mongo:/data/db \
    mongo \
    /usr/local/bin/mongod --smallfiles

  sudo docker run -d \
    --name ${CLUSTER_NAME}_elastic \
    --volume $CALL_ROOT/elastic:/data \
    dockerfile/elasticsearch
}

function shutdown {
  sudo docker stop ${CLUSTER_NAME}_mysql ${CLUSTER_NAME}_mongo ${CLUSTER_NAME}_elastic
  sudo docker rm ${CLUSTER_NAME}_mysql ${CLUSTER_NAME}_mongo ${CLUSTER_NAME}_elastic
}


# Create a new instance

function new {
  NAME=${1-`pwgen 6 1`}
  local DIR=$CALL_ROOT/instances/$NAME
  mkdir -p $DIR

  ln -sfn $CALL_ROOT/cluster.sh $DIR/instance.sh
  echo "$VERSION" > $DIR/version.txt

  mkdir -p $DIR/data
  mkdir -p $DIR/log

  touch $DIR/kor.app.yml

  KOR_DB_NAME="kor_$NAME"
  KOR_DB_USERNAME="kor_$NAME"
  KOR_DB_PASSWORD=`pwgen 20 1`
  db "grant all on $KOR_DB_NAME.* to '$KOR_DB_USERNAME'@'%' identified by '$KOR_DB_PASSWORD'"

  DB_USERNAME=$KOR_DB_USERNAME
  DB_PASSWORD=$KOR_DB_PASSWORD
  DB_NAME=$KOR_DB_NAME
  tpl $CLUSTER_SCRIPT_ROOT/templates/database.yml $DIR/database.yml
  tpl $CLUSTER_SCRIPT_ROOT/templates/mysql.cnf $DIR/mysql.cnf
  tpl $CLUSTER_SCRIPT_ROOT/templates/config.sh $DIR/config.sh
  tpl $CLUSTER_SCRIPT_ROOT/templates/kor.yml $DIR/kor.yml
  tpl $CLUSTER_SCRIPT_ROOT/templates/contact.txt.example $DIR/contact.txt
  tpl $CLUSTER_SCRIPT_ROOT/templates/help.yml.example $DIR/help.yml
  tpl $CLUSTER_SCRIPT_ROOT/templates/legal.txt.example $DIR/legal.txt

  $DIR/instance.sh init
}


# Establish database connection (and run SQL statement)

function db {
  local SQL=$1

  if [ -z "$SQL" ]; then
    sudo docker run --rm -ti \
      --link ${CLUSTER_NAME}_mysql:mysql \
      --volume $CALL_ROOT:/host \
      mysql \
      mysql --defaults-extra-file=/host/mysql.cnf
  fi

  if [ ! -z "$SQL" ]; then
    sudo docker run --rm \
      --link ${CLUSTER_NAME}_mysql:mysql \
      --volume $CALL_ROOT:/host \
      mysql \
      mysql --defaults-extra-file=/host/mysql.cnf -e "$SQL"
  fi
}


# Dump the instance database to the instance dir

function snapshot {
  local TS=`date +"%Y%m%d_%H%M%S"`

  local DIR=$CALL_ROOT/../../snapshots
  mkdir -p $DIR
  DIR=`expand_path $DIR`

  stop

  sudo docker run --rm \
    --link ${CLUSTER_NAME}_mysql:mysql \
    --volume $CALL_ROOT:/host \
    mysql \
    mysqldump --defaults-extra-file=/host/mysql.cnf $DB_NAME \
    | gzip -c > $CALL_ROOT/db.sql.gz

  sudo docker run --rm \
    --link ${CLUSTER_NAME}_mongo:mongo \
    --volume $CALL_ROOT:/host \
    mongo \
    mongoexport --host mongo --db $DB_NAME --collection attachments --jsonArray \
    | gzip -c > $CALL_ROOT/json.sql.gz

  tar czf $DIR/$NAME.$TS.$VERSION.tar.gz -C $CALL_ROOT --exclude=instance.sh --exclude=config.sh --exclude=database.yml --exclude=mysql.cnf .
  rm $CALL_ROOT/db.sql.gz

  start
}


# Import the dump from the instance dir to the database

function import {
  local FILE=$1

  stop

  mv $CALL_ROOT $CALL_ROOT.old
  mkdir -p $CALL_ROOT

  # sudo rm -rf $CALL_ROOT/data $CALL_ROOT/log
  tar xzf $FILE -C $CALL_ROOT/

  mv $CALL_ROOT.old/{instance.sh,config.sh,database.yml,mysql.cnf} $CALL_ROOT/

  zcat $CALL_ROOT/db.sql.gz | sudo docker run --rm -i \
    --link ${CLUSTER_NAME}_mysql:mysql \
    --volume $CALL_ROOT:/host \
    mysql \
    mysql --defaults-extra-file=/host/mysql.cnf $DB_NAME

  zcat $CALL_ROOT/mongo.json.gz | sudo docker run --rm -i \
    --link ${CLUSTER_NAME}_mongo:mongo \
    --volume $CALL_ROOT:/host \
    mongo \
    mongoimport --drop --host mongo --db $DB_NAME --collection attachments --jsonArray

  rm $CALL_ROOT/db.sql.gz
  rm -rf $CALL_ROOT.old

  start
}


# Upgrade

function upgrade {
  local TO=$1

  stop

  sed -i -E "s/^VERSION\=.*$/VERSION=$TO/" $CALL_ROOT/config.sh

  VERSION=$TO
  migrate

  start
}


# KOR command

function run {
  local COMMAND="$1"

  sudo docker run --rm -ti \
    --volume $CALL_ROOT:/opt/kor/shared \
    --volume $CLUSTER_ROOT/ssmtp:/etc/ssmtp \
    --link ${CLUSTER_NAME}_mysql:mysql \
    --link ${CLUSTER_NAME}_elastic:elastic \
    --link ${CLUSTER_NAME}_mongo:mongo \
    --add-host dockerhost:`docker_host_ip` \
    docker.coneda.net:443/kor:$VERSION \
    /bin/bash -c "$COMMAND" kor
}

function run_headless {
  local COMMAND="$1"

  sudo docker run --rm \
    --attach STDOUT --attach STDERR \
    --volume $CALL_ROOT:/opt/kor/shared \
    --volume $CLUSTER_ROOT/ssmtp:/etc/ssmtp \
    --link ${CLUSTER_NAME}_mysql:mysql \
    --link ${CLUSTER_NAME}_elastic:elastic \
    --link ${CLUSTER_NAME}_mongo:mongo \
    --add-host dockerhost:`docker_host_ip` \
    docker.coneda.net:443/kor:$VERSION \
    /bin/bash -c "$COMMAND" kor
}

function job {
  local COMMAND="$1"

  sudo docker run --rm \
    --volume $CALL_ROOT:/opt/kor/shared \
    --volume $CLUSTER_ROOT/ssmtp:/etc/ssmtp \
    --link ${CLUSTER_NAME}_mysql:mysql \
    --link ${CLUSTER_NAME}_elastic:elastic \
    --link ${CLUSTER_NAME}_mongo:mongo \
    --add-host dockerhost:`docker_host_ip` \
    docker.coneda.net:443/kor:$VERSION \
    /bin/bash -c "$COMMAND" kor
}


# Migrate the instance

function migrate {
  run "bundle exec rake db:migrate"
  run "bundle exec rake kor:index:drop kor:index:create kor:index:refresh"
}


# Init the instance

function init {
  run_headless "bundle exec rake db:create db:setup"
  run_headless "bundle exec rake kor:index:drop kor:index:create kor:index:refresh"
}


# Start the instance

function start {
  sudo docker run -d \
    --name ${CLUSTER_NAME}_bg_$NAME \
    --volume $CALL_ROOT:/opt/kor/shared \
    --volume $CLUSTER_ROOT/ssmtp:/etc/ssmtp \
    --link ${CLUSTER_NAME}_mysql:mysql \
    --link ${CLUSTER_NAME}_elastic:elastic \
    --link ${CLUSTER_NAME}_mongo:mongo \
    --add-host dockerhost:`docker_host_ip` \
    docker.coneda.net:443/kor:$VERSION \
    /bin/bash -c "bundle exec rake jobs:work" kor

  sudo docker run -d \
    --name ${CLUSTER_NAME}_instance_$NAME \
    --volume $CALL_ROOT:/opt/kor/shared \
    --volume $CLUSTER_ROOT/ssmtp:/etc/ssmtp \
    --link ${CLUSTER_NAME}_mysql:mysql \
    --link ${CLUSTER_NAME}_elastic:elastic \
    --link ${CLUSTER_NAME}_mongo:mongo \
    --add-host dockerhost:`docker_host_ip` \
    --publish 127.0.0.1:$PORT:8000 \
    docker.coneda.net:443/kor:$VERSION \
    /bin/bash -c "bundle exec puma -e production -p 8000 -t 2 config.ru" kor
}


# Stop the instance

function stop {
  sudo docker stop ${CLUSTER_NAME}_instance_$NAME
  sudo docker stop ${CLUSTER_NAME}_bg_$NAME

  sudo docker rm ${CLUSTER_NAME}_instance_$NAME
  sudo docker rm ${CLUSTER_NAME}_bg_$NAME
}


# Run

$1 "${@:2}"