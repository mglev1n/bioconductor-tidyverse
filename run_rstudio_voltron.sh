#!/bin/bash

set -u
set -o pipefail

args=$@
rstudio_workdir=$HOME/.lsf_jobs/rstudio_jobs
# password_file=$rstudio_workdir/.rstudio_onthefly_password
ncpus=1
mem=16384
host="null"
timelimit="18:00"
# project="acc_null"
jobname="rstudio"
queue="voltron_rstudio"
resource="null"
# image="null"
image=/project/damrauer_shared/rstudio/bioconductor-tidyverse_singularity-latest.sif


echoinfo () 
{
  echo -e "\033[1m[INFO] \033[0m $@"
}

echoerror ()
{
  echo -e "\033[31m[ERROR] $@\033[0m"
}

echoalert ()
{
  echo -e "\033[34;5m[INFO] $@\033[0m"
}

help_msg ()
{
  echo ""
  echo "This script is to submit a Singularity containerized RStudio server web instance inside an LSF job for users."
  echo ""
}

usage_msg ()
{
  echo ""
  echo "run_rstudio.sh  -n <number_of_CPU_slots> -m <hosts> -M <memory_MB_per_slot> -W <hh:mm>"
  echo "                        -J <jobname> -q <queue name> "
  echo "                        --image <rstudio_singularity_image_file>"
  echo ""
  echo "-n | --ncpus    Number of CPU slots, will be allocated in one host using -R 'span[nhost=1]' default 1 if not specified."
  echo "-m | --host   (Optional) Specify *one* host/host group you would like the job to run eg lc01e[02-30]"
  echo "-M | --mem    Memory in Megabytes per CPU slot, used for resource request, default 16384 MB. -R 'rusage[mem=16384]'"
  echo "-W | --timelimit    Wall time for the job, format HH:MM. Default is 18:00 hours"
  echo "-J | --jobname    Specify the job name, default rstudio"
  echo "-q | --queue    Specify the queue name, default damrauer_normal"
  echo "-R      Optional resource, eg himem, v100, a100"
  echo "-i | --image    Image file you specified other than the default."
  echo "-h | --help   Help message"
  echo ""

  echo "Files and directories:"
  echo "$rstudio_workdir      The directory where this script generates the job submission scripts. "

  echo ""
  echo "Job output and error files will be saved in the current working directory when you run this script. "
  echo "If job is still running, use bpeek <jobid> to check the output"
  echo ""

}

run_as_user_check ()
{
  myid=`id -u`
  if [[ $myid -lt 1000 ]];
  then
    echoerror "This script should be executed by users with UIDNumber > 1000. Exiting."
    exit 1;
  fi 
}

create_rstudio_passwd_on_file ()
{
  password1='1'
  password2='2'
  
  read -sp "  Set a runtime password for your web, don't use your work email password: " password1
  printf "\n"
  while [[ $password1 = "" ]]
  do
    echoerror "  Password is empty, please input again... "
  done

  counter=0
  while [[ $password1 != $password2 ]];
  do
    read -sp "  Confirm password: " password2
    printf "\n"

    if [[ $password1 != $password2 ]];
    then
      echoerror "  Passwords do not agree, try again..."
      let counter+=1

      if [[ $counter -lt 3 ]];
      then
        continue;
      else
        echoerror "  Failed 3 times, aborting..."
        exit 1;
      fi
    fi  
  done

  password=$password1

  # write to file
  mkdir -p `dirname $password_file`
  echo "# Password generated by run_rstudio.sh" >> $password_file
  echo "export RSTUDIO_PASSWORD=$password" >> $password_file
  
}
  

check_set_runtime_password ()
{
  if [[ ! -f $password_file ]]
  then
    echoinfo "$password_file is not found, we need to create it."
    
    create_rstudio_passwd_on_file 
  fi
}


parse_args ()
{
  while [[ $# -gt 0 ]]
  do
  key="$1"

  case $key in
    -n|--ncpus)
    ncpus=$2
    shift
    shift
    ;;

    -m|--host)
    host="$2"
    shift
    shift
    ;;

    -M|--mem)
    mem=$2
    shift
    shift
    ;;

    -W|--timelimit)
    timelimit="$2"
    shift
    shift
    ;;

    # -P|--project)
    # project="$2"
    # shift
    # shift
    # ;;

    -J|--jobname)
    jobname="$2"
    shift
    shift
    ;;

                -q|--queue)
                queue="$2"
                shift
                shift
                ;;

                -R|--resource)
                resource="$2"
                shift
                shift
                ;;

    -i|--image)
    image="$2"
    shift
    shift
    ;;

    -h|--help)
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


check_inputs ()
{
  # check workdir
  if [[ ! -d $rstudio_workdir ]];
  then
    mkdir -p $rstudio_workdir
  fi

  # check image
  if [[ $image == "null" ]];
  then
    echoinfo "Image not specified"
    exit 2
  else
    if [[ ! -f $image ]];
    then
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

check_active_jobs () 
{
  if [[ `bjobs -J $jobname -noheader 2>/dev/null` != *"$jobname"* ]]; then
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
        [yY][eE][sS]|[yY]) 
            # echo "Submitting current job..."
            return
            ;;
        *)
            echo "Quitting..."
            echo ""
            exit 1;
            ;;
    esac
  fi

  # echo "$active_jobs" | wc -l
}

write_bjob_file ()
{
  # write a bjob script for the user in the $rstudio_workdir for user 
  
  jobfile=job_$(date +'%Y%m%d_%H%M%S.%N')
  cat <<EOF > $rstudio_workdir/$jobfile
#!/bin/bash

## Auto generated script for rstudio web job.

#BSUB -J $jobname
#BSUB -n $ncpus
#BSUB -q $queue 
EOF

if [[ $resource != "null" ]];
then
  cat <<EOF >> $rstudio_workdir/$jobfile
#BSUB -R $resource
EOF
fi


cat <<EOF >> $rstudio_workdir/$jobfile
#BSUB -W $timelimit
#BSUB -M $mem
#BSUB -R "rusage[mem=$mem]"
#BSUB -oo ${rstudio_workdir}/rstudio_%J.out
#BSUB -eo ${rstudio_workdir}/rstudio_%J.err


LOGINHOST=scisub7

module load python/3.6.1

workdir=\$(python -c 'import tempfile; print(tempfile.mkdtemp())')
SIF=$image
PORT=${RSTUDIO_PORT:-8787}
# bold=\$(tput bold)
# normal=\$(tput sgr0)
MEMORY=$mem


mkdir -p -m 700 \${workdir}/run \${workdir}/tmp \${workdir}/var/lib/rstudio-server
cat > \${workdir}/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

cat > \${workdir}/rsession.sh <<END
#!/bin/sh
module load python/3.6.1
#export OMP_NUM_THREADS=\${LSB_DJOB_NUMPROC}
export OPENBLAS_NUM_THREADS=1
export LOGINHOST=scisub7
export R_LIBS_USER=\${HOME}/R/rocker-rstudio/4.0
export RS_LOGGER_TYPE=syslog

exec rsession
END

chmod +x \${workdir}/rsession.sh


cat > \${HOME}/.Rprofile <<'END'
# Write Dummy LSF commands ------------------------------------------------
add_host_command <- function(host_exec, local_exec, dir) {
  fs::dir_create(here::here(dir))
  file.create(here::here(dir, local_exec))
  cat("#!/bin/bash", file = here::here(dir, local_exec), sep = "\n")
  cat(glue::glue("ssh -i ~/.ssh/id_rsa {Sys.getenv('USER')}@scisub7 {host_exec} \$@"), file = here::here(dir, local_exec), sep = "", append = TRUE)
  fs::file_chmod(here::here(dir, local_exec), "+x")
}

add_host_command("/lsf/10.1/linux3.10-glibc2.17-x86_64/bin/bsub", "bsub", "~/R/rocker-rstudio/bin/")
add_host_command("/lsf/10.1/linux3.10-glibc2.17-x86_64/bin/bjobs", "bjobs", "~/R/rocker-rstudio/bin/")
add_host_command("/lsf/10.1/linux3.10-glibc2.17-x86_64/bin/bpeek", "bpeek", "~/R/rocker-rstudio/bin/")
add_host_command("/lsf/10.1/linux3.10-glibc2.17-x86_64/bin/bkill", "bkill", "~/R/rocker-rstudio/bin/")
add_host_command("/lsf/10.1/linux3.10-glibc2.17-x86_64/bin/bqueues", "bqueues", "~/R/rocker-rstudio/bin/")
rm(add_host_command)


# Update Path -------------------------------------------------------------
old_path <- Sys.getenv("PATH")
Sys.setenv(PATH = paste(old_path, "${HOME}/R/rocker-rstudio/bin", sep = ":"))
# Sys.setenv(PATH = paste(old_path, "/lsf/10.1/linux3.10-glibc2.17-x86_64/etc", "/lsf/10.1/linux3.10-glibc2.17-x86_64/bin" , sep = ":"))
rm(old_path)

END



# export SINGULARITY_BIND="\${workdir}/run:/run, \${workdir}/tmp:/tmp, \${workdir}/database.conf:/etc/rstudio/database.conf, \${workdir}/rsession.sh:/etc/rstudio/rsession.sh, \${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server, /project/PMBB/:/project/PMBB/, /scratch/:\${HOME}/roubaix/scratch/, /lsf/10.1/linux3.10-glibc2.17-x86_64/bin/:/lsf/10.1/linux3.10-glibc2.17-x86_64/bin/, /lsf/conf/:/lsf/conf/, /lsf/10.1/linux3.10-glibc2.17-x86_64/etc/:/lsf/10.1/linux3.10-glibc2.17-x86_64/etc/"
export SINGULARITY_BIND="\${workdir}/run:/run, \${workdir}/tmp:/tmp, \${workdir}/database.conf:/etc/rstudio/database.conf, \${workdir}/rsession.sh:/etc/rstudio/rsession.sh, \${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server, /project/:/project/, /project/damrauer_shared/:/project/damrauer_shared/, /scratch/:\${HOME}/${HOSTNAME}/scratch/, /appl/:/appl/, /lsf/:/lsf/, /scratch/:/scratch"



# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_USER=\$(id -un)
export SINGULARITYENV_PASSWORD=\$(openssl rand -base64 15)

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

echo -e "Starting RStudio Server session with \${LSB_MAX_NUM_PROCESSORS} core(s) and \$((MEMORY/1000))GB of RAM per core..."
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

module load singularity/3.8.3

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

submit_job ()
{
  echo ""
  echoinfo "Submitting $jobname job..."
  output=$(bsub < $rstudio_workdir/$jobfile)
  if [[ "$?" -ne 0 ]];
  then
    echoerror "Submit job failed. "
  else
    echo $output
    jobid=$(echo $output | awk -F'<|>' '{ print $2 }')
    
    echoinfo "See below for access instructions once job starts."
    sleep 5

    while true
    do
      out=`bpeek $jobid`
      rc=$?

      if [[ $rc -eq 0 ]];
      then
        if [[ $out != *terminal* ]];
        then
          echoinfo "Job is running, wait for link"
        else
          bpeek $jobid
          break
        fi
      elif [[ $rc -eq 255 ]];
      then
                                status=`bjobs -o "stat" -noheader $jobid`

                                if [[ $status = "EXIT" ]];
                                then
                                        echoerror "Job died, exit... Please try to rerun the command."
                                        exit 1;
                                elif [[ $status = "PEND" ]];
                                then
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

main () 
{

  # run_as_user_check
  # check_set_runtime_password
  parse_args $args
  check_inputs
  check_active_jobs
  write_bjob_file
  submit_job

}

main


