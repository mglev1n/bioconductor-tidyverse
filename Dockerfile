FROM bioconductor/bioconductor_docker:RELEASE_3_17

## Add system packages
RUN apt-get update && apt-get -y install \
     cmake \
     openssh-client \
     libssh-dev \
     libcurl4-openssl-dev \
     pandoc \
     pandoc-citeproc \
     curl \
     gdebi-core \
     && apt-get clean \
     && rm -rf /var/lib/apt/lists/*
     
## Add intel-mkl
RUN apt-get update -y && apt-get install -y wget gnupg

RUN wget -q https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
RUN apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
RUN echo "deb https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list
RUN rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB

RUN apt-get update -y && apt-get install -y intel-oneapi-mkl

## Install quarto
RUN curl -LO https://quarto.org/download/latest/quarto-linux-amd64.deb
RUN gdebi --non-interactive quarto-linux-amd64.deb

## Install Bioconductor Packages   
RUN R -e 'BiocManager::install("rtracklayer")' \
     && rm -rf /tmp/downloaded_packages/
    
## Install tidyverse
RUN /rocker_scripts/install_tidyverse.sh

## Update Arrow with compression libraries
RUN R -e 'arrow::install_arrow(minimal = FALSE)' \
     && rm -rf /tmp/downloaded_packages/

# Install custom packages
RUN mkdir -p /installation_scripts
COPY scripts/install_packages.sh /installation_scripts
WORKDIR /installation_scripts
RUN chmod +x install_packages.sh
RUN --mount=type=secret,id=GITHUB_PAT \
     export GITHUB_PAT=$(cat /run/secrets/GITHUB_PAT)

RUN ./install_packages.sh
  
LABEL org.opencontainers.image.source=https://github.com/mglev1n/bioconductor-tidyverse

