FROM bioconductor/bioconductor_docker:latest

## Add SSH
RUN apt-get update && apt-get install -y \
  openssh-client \
  libssh-dev

## Install tidyverse
RUN /rocker_scripts/install_tidyverse.sh

## Install R packages
RUN install2.r --error --skipinstalled --ncpus -1 \
    here \
    tidymodels

## Install bioconductor Packages   
RUN R -e 'BiocManager::install("rtracklayer")'

RUN rm -rf /tmp/downloaded_packages
  
LABEL org.opencontainers.image.source=https://github.com/mglev1n/bioconductor-tidyverse
