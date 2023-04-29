#!/bin/sh

## Install R packages
install2.r --error --skipinstalled --ncpus -1 \
    babelwhale \
    broom \
    data.table \
    clustermq \
    future.callr \
    future.batchtools \
    ggpubr \
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
    
## Install MRC-IEU packages
## && R -e 'remotes::install_github("mrcieu/gwasglue")' \
R -e 'remotes::install_github("MRCIEU/TwoSampleMR")' \
    && R -e 'remotes::install_github("mrcieu/ieugwasr")' \
    && R -e 'remotes::install_github("explodecomputer/genetics.binaRies")' \
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
    && install2.r --error --skipinstalled --ncpus -1 \
       quadprog \
       tidygenomics \
       vcfR \
       tidygraph \
       ggraph \
    && rm -rf /tmp/downloaded_packages/
