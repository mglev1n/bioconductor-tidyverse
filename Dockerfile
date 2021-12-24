FROM bioconductor/bioconductor_docker:latest

## Install tidyverse
RUN /rocker_scripts/install_tidyverse.sh

## Install bioconductor Packages   
RUN R -e 'BiocManager::install("rtracklayer")'

RUN rm -rf /tmp/downloaded_packages
  
LABEL org.opencontainers.image.source=https://github.com/mglev1n/bioconductor-tidyverse
