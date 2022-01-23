FROM bioconductor/bioconductor_docker:RELEASE_3_14
     
RUN mkdir -p /installation_scripts
COPY scripts/install_packages.sh /installation_scripts
WORKDIR /installation_scripts
RUN chmod +x install_packages.sh

RUN --mount=type=secret,id=GITHUB_PAT \
     export GITHUB_PAT=$(cat /run/secrets/GITHUB_PAT) && \
     ./install_packages.sh
  
LABEL org.opencontainers.image.source=https://github.com/mglev1n/bioconductor-tidyverse
