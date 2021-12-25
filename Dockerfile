FROM bioconductor/bioconductor_docker:devel

## Add SSH
RUN apt-get update && apt-get install -y \
  openssh-client \
  libssh-dev

## Install bioconductor Packages   
RUN R -e 'BiocManager::install("rtracklayer")' \
    && rm -rf /tmp/downloaded_packages/
    
## Install tidyverse
RUN /rocker_scripts/install_tidyverse.sh

## Install R packages
RUN install2.r --error --skipinstalled --ncpus -1 \
    broom \
    data.table \
    clustermq \
    future.callr \
    glue \
    here \
    lubridate \
    metafor \
    qs \
    tarchetypes \
    targets \
    tidygraph \
    tidymodels \
    visNetwork \
    && rm -rf /tmp/downloaded_packages/
  
LABEL org.opencontainers.image.source=https://github.com/mglev1n/bioconductor-tidyverse
