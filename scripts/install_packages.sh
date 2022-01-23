env

R -e 'Sys.getenv()'

## Add system packages
apt-get update && apt-get install -y \
  cmake \
  openssh-client \
  libssh-dev

## Install bioconductor Packages   
R -e 'BiocManager::install("rtracklayer")' \
    && rm -rf /tmp/downloaded_packages/
    
## Install tidyverse
/rocker_scripts/install_tidyverse.sh

## Install R packages
install2.r --error --skipinstalled --ncpus -1 \
    broom \
    data.table \
    clustermq \
    future.callr \
    future.batchtools \
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
R -e 'arrow::install_arrow(minimal = FALSE)' \
    && rm -rf /tmp/downloaded_packages/
    
## Install MRC-IEU packages
R -e 'remotes::install_github("MRCIEU/TwoSampleMR")' \
    && R -e 'remotes::install_github("mrcieu/ieugwasr")' \
    && R -e 'remotes::install_github("explodecomputer/genetics.binaRies")' \
    && R -e 'remotes::install_github("mrcieu/gwasglue")' \
    && rm -rf /tmp/downloaded_packages/

## Install my custom packages
R -e 'remotes::install_github("mglev1n/annotateR")' \
    && R -e 'remotes::install_github("mglev1n/locusplotr")' \
    && rm -rf /tmp/downloaded_packages/
    
## Install Genomic-SEM related packages
R -e 'remotes::install_github("cjvanlissa/tidySEM")' \
    && R -e 'remotes::install_github("GenomicSEM/GenomicSEM")' \
    && install2.r --error --skipinstalled --ncpus -1 \
       corrr \
       gdata \
       heatmaply \
       lavaan \
       && rm -rf /tmp/downloaded_packages/

## Install Miscellaneous Genomics Packages
R -e 'remotes::install_github("privefl/bigsnpr")' \
    && R -e 'remotes::install_github("jrs95/hyprcoloc", build_opts = c("--resave-data", "--no-manual"), build_vignettes = TRUE)' \
    && R -e 'remotes::install_github("chr1swallace/coloc@main", build_vignettes=TRUE)' \
    && R -e 'BiocManager::install("VariantAnnotation")' \
    && install2.r --error --skipinstalled --ncpus -1 \
       quadprog \
       tidygenomics \
       vcfR \
       tidygraph \
       ggraph \
    && rm -rf /tmp/downloaded_packages/