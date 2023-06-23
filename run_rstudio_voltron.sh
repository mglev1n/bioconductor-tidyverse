#!/bin/bash

set -u
set -o pipefail

###################################################################
# Set default command line options and variables
args=$@
rstudio_workdir=$HOME/.lsf_jobs/rstudio_jobs
ncpus=1
mem=16384
host="null"
timelimit="18:00"
jobname="rstudio"
queue="voltron_rstudio"
resource="null"
image=/project/voltron/rstudio/containers/bioconductor-tidyverse_3.17.sif

###################################################################
# Create functions that enable stylized command-line output
echoinfo() {
  echo -e "\033[1m[INFO] \033[0m $@"
}

echoerror() {
  echo -e "\033[31m[ERROR] $@\033[0m"
}

echoalert() {
  echo -e "\033[34;5m[INFO] $@\033[0m"
}

###################################################################
# Help and usage messages
help_msg() {
  echo ""
  echo "This script is to submit a Singularity containerized RStudio server web instance inside an LSF job for users."
  echo ""
}

usage_msg() {
  echo ""
  echo "run_rstudio.sh  -n <number_of_CPU_slots> -m <hosts> -M <memory_per_slot> -W <hh:mm>"
  echo "                -J <jobname> -q <queue name>"
  echo "                --image <rstudio_singularity_image_file>"
  echo ""
  echo "-n  | --ncpus     Number of CPU slots to be allocated for the container"
  echo "-m  | --host      (Optional) Specify *one* host/host group you would like the job to run eg 'roubaix'"
  echo "-M  | --mem       Memory per CPU slot, used for resource request, default '16384'"
  echo "-W  | --timelimit Wall time for the job, format HH:MM. Default is 18:00 hours"
  echo "-J  | --jobname   Specify the job name, default 'rstudio'"
  echo "-q  | --queue     Specify the queue name, default 'voltron_normal'"
  echo "-R                Optional resource, eg himem, v100, a100; currently not used by default"
  echo "-i  | --image     Optional Singularity container image file other than the default."
  echo "-h  | --help      Help message"
  echo ""

  echo "Files and directories:"
  echo "$rstudio_workdir      The directory where this script generates the job submission scripts. "

  echo ""
  echo "Job output and error files will be saved in the current working directory when you run this script. "
  echo "If job is still running, use bpeek <jobid> to check the output"
  echo ""

}

###################################################################
# Function to ensure job is being run by a user with appropriate permissions
run_as_user_check() {
  myid=$(id -u)
  if [[ $myid -lt 1000 ]]; then
    echoerror "This script should be executed by users with UIDNumber > 1000. Exiting."
    exit 1
  fi
}

###################################################################
# Function to parse the command line arguments and assign them to variables
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -n | --ncpus)
      ncpus=$2
      shift
      shift
      ;;

    -m | --host)
      host="$2"
      shift
      shift
      ;;

    -M | --mem)
      mem=$2
      shift
      shift
      ;;

    -W | --timelimit)
      timelimit="$2"
      shift
      shift
      ;;

    -J | --jobname)
      jobname="$2"
      shift
      shift
      ;;

    -q | --queue)
      queue="$2"
      shift
      shift
      ;;

    -R | --resource)
      resource="$2"
      shift
      shift
      ;;

    -i | --image)
      image="$2"
      shift
      shift
      ;;

    -h | --help)
      # help_msg
      usage_msg
      exit 0
      ;;

    *)
      echoerror “Invalid flag. $1 is not a valid option.”
      exit 1
      ;;

    esac
  done

}

###################################################################
# Ensure that the necessary variables/arguments have been provided
check_inputs() {
  # check workdir
  if [[ ! -d $rstudio_workdir ]]; then
    mkdir -p $rstudio_workdir
  fi

  # check image
  if [[ $image == "null" ]]; then
    echoinfo "Image not specified"
    exit 2
  else
    if [[ ! -f $image ]]; then
      echoerror "You specified image file $image does not exist. Quit."
      exit 2
    else
      echoinfo "Using specified image: $image"
    fi
  fi

  echoinfo "Parameters used are: "
  echoinfo "-n  $ncpus"
  echoinfo "-m  $host"
  echoinfo "-M  $mem"
  echoinfo "-W  $timelimit"
  # echoinfo "-P  $project"
  echoinfo "-J  $jobname"
  echoinfo "-q  $queue"
  echoinfo "-R  $resource"
  echoinfo "-i  $image"

}

###################################################################
# Check if other active jobs are running for this user; prevents loading multiple redundant jobs that may interfere with eachother
check_active_jobs() {
  if [[ $(bjobs -J $jobname -noheader 2>/dev/null) != *"$jobname"* ]]; then
    echo ""
    echoinfo "No other active $jobname jobs submitted by $(whoami)."
    return
  else
    echo ""
    echoinfo "The following active $jobname jobs have already been submitted by $(whoami):"
    bjobs -J $jobname
    echo ""
    read -r -p "Are you sure you would like to submit a new job (rather than accessing or killing the running job[s])? (Yes/No): " response
    case "$response" in
    [yY][eE][sS] | [yY])
      # echo "Submitting current job..."
      return
      ;;
    *)
      echo "Quitting..."
      echo ""
      exit 1
      ;;
    esac
  fi

  # echo "$active_jobs" | wc -l
}

###################################################################
# Function which compiles/writes the bjob file needed to launch the selected image
write_bjob_file() {
  # write a bjob script for the user in the $rstudio_workdir for user

  jobfile=job_$(date +'%Y%m%d_%H%M%S.%N')
  cat <<EOF >$rstudio_workdir/$jobfile
#!/bin/bash

## Auto generated script for rstudio web job.

#BSUB -J $jobname
#BSUB -n $ncpus
#BSUB -q $queue 
EOF

  if [[ $resource != "null" ]]; then
    cat <<EOF >>$rstudio_workdir/$jobfile
#BSUB -R $resource
EOF
  fi

  cat <<EOF >>$rstudio_workdir/$jobfile
#BSUB -W $timelimit
#BSUB -M $mem
#BSUB -R "rusage[mem=$mem]"
#BSUB -oo ${rstudio_workdir}/rstudio_%J.out
#BSUB -eo ${rstudio_workdir}/rstudio_%J.err

###################################################################
# Set environment variables
LOGINHOST=scisub7
SIF=$image
PORT=${RSTUDIO_PORT:-8787}
MEMORY=$mem
IMAGE_BASENAME=$(basename "${image%.*}")

###################################################################
# Create temporary working directory
module load python
workdir=\$(python -c 'import tempfile; print(tempfile.mkdtemp())')
mkdir -p -m 700 \${workdir}/run \${workdir}/tmp \${workdir}/var/lib/rstudio-server

###################################################################
# Create temporary database
cat > \${workdir}/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

###################################################################
# Create bash script that runs within the container immediately before launching rstudio; used to set environment variables
cat > \${workdir}/rsession.sh <<END
#!/bin/sh
module load python
export OMP_NUM_THREADS=\${LSB_DJOB_NUMPROC}
export OPENBLAS_NUM_THREADS=\${LSB_DJOB_NUMPROC}
export LOGINHOST=scisub7
export R_LIBS_USER=\${HOME}/R/rocker-rstudio/\${IMAGE_BASENAME}
export RS_LOGGER_TYPE=syslog

export LSB_DEFAULTQUEUE=\${LSB_DEFAULTQUEUE}
export LSF_SERVERDIR=\${LSF_SERVERDIR}
export LSF_BINDIR=\${LSF_BINDIR}
export LSF_ENVDIR=\${LSF_ENVDIR}
export LSF_LIBDIR=\${LSF_LIBDIR}
export MODULESHOME=\${MODULESHOME}
export MODULEPATH=\${MODULEPATH}
export MODULE_VERSION=\${MODULE_VERSION}
export MODULE_VERSION_STACK=\${MODULE_VERSION_STACK}

exec /usr/lib/rstudio-server/bin/rsession 
END

chmod +x \${workdir}/rsession.sh


###################################################################
# Update the user's .Rprofile to load important environment variables
# cat > \${HOME}/.Rprofile <<'END'
# # Update Env -------------------------------------------------------------
# Sys.setenv(LSB_DEFAULTQUEUE = "${LSB_DEFAULTQUEUE}")
# Sys.setenv(LSF_SERVERDIR = "${LSF_SERVERDIR}")
# Sys.setenv(LSF_BINDIR = "${LSF_BINDIR}")
# Sys.setenv(LSF_ENVDIR = "${LSF_ENVDIR}")
# Sys.setenv(LSF_LIBDIR = "${LSF_LIBDIR}")
# Sys.setenv(MODULESHOME = "${MODULESHOME}")
# Sys.setenv(MODULEPATH = "${MODULEPATH}")
# Sys.setenv(MODULE_VERSION = "${MODULE_VERSION}")
# Sys.setenv(MODULE_VERSION_STACK = "${MODULE_VERSION_STACK}")
# 
# END


###################################################################
# Define singularity environment variables (eg. directories to be mounted to the container)
export SINGULARITY_BIND="\${workdir}/run:/run, \${workdir}/tmp:/tmp, /lsf:/lsf, \${workdir}/database.conf:/etc/rstudio/database.conf, \${workdir}/rsession.sh:/etc/rstudio/rsession.sh, \${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server, /project/:/project/, /appl/:/appl/, /lsf/:/lsf/, /scratch/:/scratch, /static:/static"
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_USER=\$(id -un)
export SINGULARITYENV_PASSWORD=\$(openssl rand -base64 15)

###################################################################
# get unused socket per https://unix.stackexchange.com/a/132524 - used another function from here: https://gist.github.com/pansapiens/b46071f99dcd1f374354c1687f7a986a
# Function to find an available port to run the RStudio server from: https://gist.github.com/pansapiens/b46071f99dcd1f374354c1687f7a986a
function get_port {
    # lsof doesn't return open ports for system services, so we use netstat
    # until ! lsof -i -P -n | grep -qc ':'\${PORT}' (LISTEN)';
    
    until ! netstat -ln | grep "  LISTEN  " | grep -iEo  ":[0-9]+" | cut -d: -f2 | grep -wqc \${PORT};
    do
        ((PORT++))
        echo "Checking port: \${PORT}"
    done
    echo "Got one: \${PORT}"
}

echo ""
echo "Finding an available port ..."
get_port

PORT=\${PORT}

echo -e "Starting RStudio Server session with \${LSB_MAX_NUM_PROCESSORS} core(s) and \$((MEMORY/1000))GB of RAM..."
echo
echo -e "1. Create an SSH tunnel from your local workstation to the server by executing the following command in a new terminal window:"
echo
echo -e "   \033[1m ssh -N -L \${PORT}:\${HOSTNAME}:\${PORT} \${SINGULARITYENV_USER}@\${LOGINHOST}.pmacs.upenn.edu \033[0m"
echo
echo -e "2. Navigate your web browser to:"  
echo
echo -e "   \033[1m http://localhost:\${PORT} \033[0m"
echo
echo -e "3. Login to RStudio Server using the following credentials:"
echo
echo -e "   \033[1m user: \${SINGULARITYENV_USER} \033[0m"
echo -e  "   \033[1m password: \${SINGULARITYENV_PASSWORD} \033[0m"
echo
echo "When finished using RStudio Server, terminate the job:"
echo
echo "1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)"
echo "2. Issue the following command on the login node (\${LOGINHOST}.pmacs.upenn.edu):"
echo
echo -e "   \033[1m bkill \${LSB_JOBID} \033[0m"


###################################################################
# Load final modules and launch container
module load singularity
export SINGULARITYENV_APPEND_PATH=\${PATH}

singularity exec --cleanenv $image \
    rserver --www-port \${PORT} \
            --auth-none=0 \
            --auth-pam-helper-path=pam-helper \
            --auth-stay-signed-in-days=30 \
            --auth-timeout-minutes=0 \
            --server-user=$(whoami)  \
            --rsession-path=/etc/rstudio/rsession.sh

if [[ "\$?" -ne "0" ]];
then
  echo "A problem occured when starting singularity container, failed. "
  exit 1
fi

sing_pid=\$!
echo "RStudio started in the singularity container with PID \$sing_pid."
echo "Making sure it is alive"

for i in {3..1};
do
  echo "Checking \$i, next check in 5 seconds."
  if ps -p \$sing_pid; 
  then
    sleep 5
  else
    echo "Container process is dead, abort"
    echo
    exit 1
  fi
done

EOF

}

submit_job() {
  echo ""
  echoinfo "Submitting $jobname job..."
  output=$(bsub <$rstudio_workdir/$jobfile)
  if [[ "$?" -ne 0 ]]; then
    echoerror "Submit job failed. "
  else
    echo $output
    jobid=$(echo $output | awk -F'<|>' '{ print $2 }')

    echoinfo "See below for access instructions once job starts."
    sleep 5

    while true; do
      out=$(bpeek $jobid)
      rc=$?

      if [[ $rc -eq 0 ]]; then
        if [[ $out != *terminal* ]]; then
          echoinfo "Job is running, wait for link"
        else
          bpeek $jobid
          break
        fi
      elif [[ $rc -eq 255 ]]; then
        status=$(bjobs -o "stat" -noheader $jobid)

        if [[ $status = "EXIT" ]]; then
          echoerror "Job died, exit... Please try to rerun the command."
          exit 1
        elif [[ $status = "PEND" ]]; then
          echoinfo "Job is pending"
        else
          :
        fi
      else # [[ $rc -eq 1 ]];
        bjobs $jobid
      fi

      sleep 5

    done
  fi
}

main() {
  run_as_user_check
  parse_args $args
  check_inputs
  check_active_jobs
  write_bjob_file
  submit_job
}

main
