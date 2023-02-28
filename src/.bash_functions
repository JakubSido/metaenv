#!/bin/bash

# Enable SCRATCH->TMP mapping
alias tmp-to-scratch='export TMPDIR=$SCRATCHDIR'

docker-to-sif() {
    docker_image=$([[ -f $1 ]] && echo $1 || echo "")
    singul_image=$([[ -z $2 ]] && echo "${docker_image}.sif" || echo $2 )

    # Check if input file exists
    if [[ -z $docker_image ]]; then
        echo_error "docker-to-sif <docker-image-file> [singularity-output-sif]"
        return 1
    fi

    # Set $SCRATCHDIR to $TMPDIR if scratchdir is available
    if [[ $SCRATCHDIR != "/scratch/${USER}" ]]; then
        tmp-to-scratch
    fi

    # Build singularity image
    singularity build "${singul_image}" "docker-archive://${docker_image}"

    echo_info "Run with: singularity shell $(realpath $singul_image)"
}

is-run() {
    cpus=$([[ $1 =~ ^[0-9]+$ ]]   && echo $1          || echo "")
    rams=$([[ $2 =~ ^[0-9]+$ ]]   && echo "$2gb"      || echo "")
    scrt=$([[ $3 =~ ^[0-9]+$ ]]   && echo "$3gb"      || echo "")
    gpus=$([[ $4 =~ ^[0-9]+$ ]]   && echo "$4"        || echo "")
    city=$([[ ! -z $5 ]]          && echo ":$5=True"  || echo "")
    queue=$([[ $gpus -eq 0 ]]     && echo "default@meta-pbs.metacentrum.cz" || echo "gpu@meta-pbs.metacentrum.cz")

    if [[ -z $cpus ]] || [[ -z $rams ]] || [[ -z $scrt ]] || [[ -z $gpus ]]; then
        echo_error "is-run <cpus> <rams-gb> <scrt-gb> <gpus> [city]"
        return 1
    fi

    qsub_command="qsub -I \
                    -p +250 \
                    -l walltime=6:0:0 -q ${queue} \
                    -l select=1:ncpus=${cpus}:ngpus=${gpus}:mem=${rams}:scratch_ssd=${scrt}${city} \
                    -- /bin/bash -c \"export HOME=${HOME} && cd ~ && /bin/bash\""

    read -p "$(echo "${qsub_command}... proceed? (y/n):" | awk '{$1=$1};1')" -n 1 -r
    echo
    if [[ $REPLY =~ ^y|Y$ ]]; then
        eval ${qsub_command}
    fi
}

# Create aliases for favourite interactive sesstion configurations
if [[ ! -z $FAVOURITE_IS_CONFIGS ]]; then
    echo_info -e "\nCreating iteractive session aliases..."

    for ((i=0; i<${#FAVOURITE_IS_CONFIGS[@]}; i++)); do
        alias_name="is-$(echo "${FAVOURITE_IS_CONFIGS[$i]}" | tr -s ' ' | tr ' ' '-')"
        alias_body="is-run ${FAVOURITE_IS_CONFIGS[$i]}"

        echo_verbose -n "creating ${alias_name}... "
        alias ${alias_name}="${alias_body}"

        if command -v ${alias_name} &> /dev/null; then
            echo_verbose -e "\033[0;32mok\033[0m"
        else
            echo_verbose -e "\033[0;31mnok!\033[0m"
        fi
    done
fi
