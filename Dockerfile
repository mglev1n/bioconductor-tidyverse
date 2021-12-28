FROM bioconductor/bioconductor_docker:RELEASE_3_14

## Add system packages
RUN apt-get update && apt-get install -y \
  cmake \
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
    
## Update Arrow with compression libraries
RUN R -e 'arrow::install_arrow(minimal = FALSE)' \
    && rm -rf /tmp/downloaded_packages/
    
## Install MRC-IEU packages
RUN R -e 'devtools::install_github("MRCIEU/TwoSampleMR")' \
    && R -e 'devtools::install_github("mrcieu/ieugwasr")' \
    && rm -rf /tmp/downloaded_packages/

## Install my custom packages
RUN R -e 'devtools::install_github("mglev1n/annotateR")' \
    && R -e 'devtools::install_github("mglev1n/locusplotr")' \
    && rm -rf /tmp/downloaded_packages/
    
## Install Genomic-SEM related packages
RUN R -e 'devtools::install_github("cjvanlissa/tidySEM")' \
    && R -e 'devtools::install_github("GenomicSEM/GenomicSEM")' \
    && install2.r --error --skipinstalled --ncpus -1 \
       corrr \
       gdata \
       heatmaply \
       lavaan \
       && rm -rf /tmp/downloaded_packages/
  
LABEL org.opencontainers.image.source=https://github.com/mglev1n/bioconductor-tidyverse
