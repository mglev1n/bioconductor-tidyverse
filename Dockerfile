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
RUN apt update
RUN apt -y install intel-oneapi-mkl

RUN update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so     libblas.so-x86_64-linux-gnu      /opt/intel/mkl/lib/intel64/libmkl_rt.so 150
RUN update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so.3   libblas.so.3-x86_64-linux-gnu    /opt/intel/mkl/lib/intel64/libmkl_rt.so 150
RUN update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so   liblapack.so-x86_64-linux-gnu    /opt/intel/mkl/lib/intel64/libmkl_rt.so 150
RUN update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so.3 liblapack.so.3-x86_64-linux-gnu  /opt/intel/mkl/lib/intel64/libmkl_rt.so 150

RUN echo "/opt/intel/lib/intel64"     >  /etc/ld.so.conf.d/mkl.conf
RUN echo "/opt/intel/mkl/lib/intel64" >> /etc/ld.so.conf.d/mkl.conf
RUN ldconfig
RUN echo "MKL_THREADING_LAYER=GNU" >> /etc/environment

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

