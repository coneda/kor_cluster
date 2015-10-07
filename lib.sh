#!/bin/bash -e

[ -z "$DIR" ] && DIR=.
[ -z "$SERVICE_ROOT" ] && SERVICE_ROOT=.
[ -z "$NAME" ] && NAME=sample
[ -z "$VERSION" ] && [ -f $CALL_ROOT/version.txt ] && VERSION=`cat $CALL_ROOT/version.txt`
[ -z "$PORT" ] && PORT=8080
[ -z "$DB_USERNAME" ] && DB_USERNAME=root
[ -z "$DB_PASSWORD" ] && DB_PASSWORD=root

function tpl {
  TEMPLATE=$1
  DESTINATION=$2

  cp $TEMPLATE $DESTINATION

  sed -i "s/{{NAME}}/$NAME/g" $DESTINATION
  sed -i "s/{{CLUSTER_NAME}}/$CLUSTER_NAME/g" $DESTINATION
  sed -i "s#{{CLUSTER_ROOT}}#$CLUSTER_ROOT#g" $DESTINATION
  sed -i "s#{{CLUSTER_PORT}}#$CLUSTER_PORT#g" $DESTINATION
  sed -i "s#{{SERVER_NAME}}#$SERVER_NAME#g" $DESTINATION
  sed -i "s/{{VERSION}}/$VERSION/g" $DESTINATION
  sed -i "s/{{PORT}}/$PORT/g" $DESTINATION
  sed -i "s#{{DIR}}#$DIR#g" $DESTINATION
  sed -i "s#{{SERVICE_ROOT}}#$SERVICE_ROOT#g" $DESTINATION
  sed -i "s#{{KOR_ROOT}}#$KOR_ROOT#g" $DESTINATION
  sed -i "s#{{ROOT}}#$ROOT#g" $DESTINATION
  sed -i "s#{{DB_USERNAME}}#$DB_USERNAME#g" $DESTINATION
  sed -i "s#{{DB_PASSWORD}}#$DB_PASSWORD#g" $DESTINATION
  sed -i "s#{{DB_NAME}}#$DB_NAME#g" $DESTINATION
  sed -i "s#{{KOR_DB_USERNAME}}#$KOR_DB_USERNAME#g" $DESTINATION
  sed -i "s#{{KOR_DB_PASSWORD}}#$KOR_DB_PASSWORD#g" $DESTINATION
  sed -i "s#{{KOR_DB_NAME}}#$KOR_DB_NAME#g" $DESTINATION
  sed -i "s#{{INSTANCE_NAME}}#$INSTANCE_NAME#g" $DESTINATION
}

function expand_path {
  cd "$1" 2> /dev/null
  echo "`pwd`"
}

function generate_password {
  pwgen 20 -n 1
}

function config {
  echo "NAME=$NAME"
  echo "VERSION=$VERSION"
  echo "PORT=$PORT"
  echo "DB_USERNAME=$DB_USERNAME"
  echo "DB_PASSWORD=$DB_PASSWORD"
}

function docker_host_ip {
  ip route | awk '/docker0/ { print $9 }'
}