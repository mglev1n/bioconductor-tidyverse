#!/bin/bash
# from: https://github.com/rocker-org/rocker-versioned2/blob/master/scripts/install_tidyverse.sh

## build ARGs
NCPUS=${NCPUS:--1}

set -e
apt-get update -qq && apt-get -y --no-install-recommends install \
    libxml2-dev \
    libcairo2-dev \
    libgit2-dev \
    default-libmysqlclient-dev \
    libpq-dev \
    libsasl2-dev \
    libsqlite3-dev \
    libssh2-1-dev \
    libxtst6 \
    libcurl4-openssl-dev \
    openssh-client \
    libssh-dev \
    unixodbc-dev && \
  rm -rf /var/lib/apt/lists/*

install2.r --error --skipinstalled -n $NCPUS \
    tidyverse \
    devtools \
    rmarkdown \
    BiocManager \
    vroom \
    gert \
    here

## dplyr database backends
install2.r --error --skipmissing --skipinstalled -n $NCPUS \
    arrow \
    dbplyr \
    DBI \
    dtplyr \
    duckdb \
    nycflights13 \
    Lahman \
    RMariaDB \
    RPostgres \
    RSQLite \
    fst
    
## tidymodels
install2.r --error --skipinstalled -n $NCPUS tidymodels

 rm -rf /tmp/downloaded_packages
