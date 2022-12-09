# bioconductor-tidyverse
This image adds tidyverse and useful genomics R packages to the base bioconductor docker image. A GitHub Actions workflow is used to automatically build Docker and Singularity images. These images are available at ghcr.io/mglev1n/bioconductor-tidyverse. The newest Docker image can be found at the `bioconductor-tidyverse:latest` tag, while the newest Singularity image can be found at the `bioconductor-tidyverse:latest-singularity` tag.

# Usage
`run_rstudio_ssh.sh` is a bash script designed to be executed on an LPC/HPC login host. This script submits a bash job to the LPC/HPC scheduler, which will start an singularity container running an instance of Rstudio server. The script contains options for changing the job specifications, including the queue, singularity image, and CPU/memory requirements. Once the script has executed, it will provide information about setting up an ssh tunnel to connect to your new Rstudio session via your local web browser. 

1. Copy `run_rstudio_ssh.sh` to a directory visible to your login host.
2. `run_rstudio_ssh.sh` is currently setup to use the `scisub7` login host on the PMACS LPC, and the `damrauer_normal` queue - modify `run_rstudio_ssh.sh` to change these defaults if necessary.
3. Download the singularity image from the github container repository to a shared directory visible from the login host. This only needs to be performed once (or whenever the image is updated). Typically involves loading the singularity module (Eg. `module load singularity`) and then downloading the container (Eg. `singularity pull docker://ghcr.io/mglev1n/bioconductor-tidyverse`). `run_rstudio_ssh.sh` can be modified to point to the location of this image.
4. Execute `run_rstudio_ssh.sh` from the login host.
5. Follow onscreen instructions for setting up an ssh tunnel to access the rstudio session from your local web browser.
