#!/bin/bash -e

COMMIT=${1-master}
PURPOSE=${2-production}

CALL_ROOT="$( cd "$( dirname "$0" )" && pwd )"
TS=`date +"%Y%m%d_%H%M%S"`
TARGET=$CALL_ROOT/tmp/$COMMIT.$TS
KOR_REPO=`cat $CALL_ROOT/repository.txt`
KOR_ROOT=$CALL_ROOT/tmp/kor

if [ -d $KOR_ROOT ]; then
  (
    cd $KOR_ROOT
    git fetch --all
    git checkout $COMMIT || echo "Pulling not possible, not on a branch"
  )
else
  git clone $KOR_REPO -b $COMMIT $KOR_ROOT
fi

mkdir -p $TARGET

if cd $KOR_ROOT && [ -f $KOR_ROOT/.ruby-version ] ; then
  cp --preserve=all $KOR_ROOT/.ruby-version $TARGET/ruby-version

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
