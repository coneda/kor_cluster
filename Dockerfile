FROM docker.coneda.net:443/ubuntu:14.04

MAINTAINER Moritz Schepp <moritz.schepp@gmail.com>

VOLUME /opt/kor/shared
EXPOSE 8000

ENV RAILS_ENV production

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y build-essential libxml2-dev libxslt-dev git-core curl libssl-dev && \
    apt-get install -y libmysqlclient-dev imagemagick libav-tools zip libreadline6-dev && \
    apt-get clean && \
    git clone https://github.com/sstephenson/rbenv.git /opt/rbenv && \
    git clone https://github.com/sstephenson/ruby-build.git /opt/rbenv/plugins/ruby-build && \
    echo 'export RBENV_ROOT=/opt/rbenv' >> /etc/profile.d/rbenv.sh && \
    echo 'export PATH=/opt/rbenv/bin:/opt/rbenv/shims:$PATH' >> /etc/profile.d/rbenv.sh && \
    echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh \
    echo '. /etc/profile.d/rbenv.sh' >> /etc/bash.bashrc \
    echo 'gem: --no-ri --no-rdoc' >> /etc/gemrc && \
    useradd -m kor
    

ENV RBENV_ROOT /opt/rbenv
ENV PATH /opt/rbenv/bin:/opt/rbenv/shims:$PATH

RUN mkdir -p /opt/kor/current && \
    mkdir -p /opt/kor/shared/data

WORKDIR /opt/kor/current

ADD ruby-version /opt/kor/ruby-version

RUN rbenv install `cat /opt/kor/ruby-version` && \
    rbenv global `cat /opt/kor/ruby-version` && \
    rbenv shims && \
    gem install bundler

ADD . /opt/kor

RUN tar xf /opt/kor/kor.tar && \
    bash -c "bundle install --path /opt/kor/bundle --without development test" kor && \
    ln -sfn /opt/kor/shared/database.yml /opt/kor/current/config/database.yml && \
    ln -sfn /opt/kor/shared/data /opt/kor/current/data && \
    ln -sfn /opt/kor/shared/log /opt/kor/current/log

RUN bash -c "bundle exec rake assets:precompile" kor
