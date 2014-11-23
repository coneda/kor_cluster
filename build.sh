#!/bin/bash -e

COMMIT=${1-master}
PURPOSE=${2-production}

CALL_ROOT="$( cd "$( dirname "$0" )" && pwd )"
TS=`date +"%Y%m%d_%H%M%S"`
TARGET=$CALL_ROOT/tmp/$COMMIT.$TS
KOR_REPO=`cat $CALL_ROOT/repository.txt`
KOR_ROOT=$CALL_ROOT/tmp/kor

rm -rf $KOR_ROOT
git clone $KOR_REPO $KOR_ROOT

(
  cd $KOR_ROOT
  git checkout -t origin/$COMMIT
)

mkdir -p $TARGET

if cd $KOR_ROOT && git show $COMMIT:.ruby-version 2> /dev/null > $TARGET/ruby-version ; then
  if [ $PURPOSE = "production" ]; then
    cp $CALL_ROOT/Dockerfile $TARGET/Dockerfile
    cd $KOR_ROOT && git archive -o $TARGET/kor.tar $COMMIT
    sudo docker build -t docker.coneda.net:443/kor:$COMMIT $TARGET
  else
    cp $CALL_ROOT/Dockerfile.test $TARGET/Dockerfile
    git archive -o $TARGET/kor.tar $COMMIT
    sudo docker build -t docker.coneda.net:443/kor:$COMMIT-test $TARGET
  fi

  rm -rf $TARGET
else
  echo "The revision '$COMMIT' doesn't specify the ruby version"
  rm -rf $TARGET
  exit 1
fi
