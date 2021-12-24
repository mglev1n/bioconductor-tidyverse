FROM bioconductor/bioconductor_docker:latest

RUN /rocker_scripts/install_tidyverse.sh

### Bioconductor Packages ###     
RUN R -e 'BiocManager::install("rtracklayer")'

RUN rm -rf /tmp/downloaded_packages
  
LABEL org.opencontainers.image.source=https://github.com/mglev1n/bioconductor-tidyverse
