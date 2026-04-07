#!/bin/bash
# Ansible SSH wrapper for GCP instances
#
# Ansible calls: ssh_executable [ssh_options] hostname [command...]
# gcloud expects: gcloud compute ssh INSTANCE -- [ssh_options] [command...]
#
# This script extracts the hostname from Ansible's SSH args and
# restructures them for gcloud compute ssh.

GCP_PROJECT="${GCP_PROJECT:-zenith-development-489709}"
GCP_ZONE="${GCP_ZONE:-europe-west3-a}"

ssh_opts=()
hostname=""
remote_cmd=()
skip_next=false

# SSH options that consume the next argument
opts_with_param="b c D E e F I i J L l m O o p Q R S W w"

for arg in "$@"; do
    if $skip_next; then
        ssh_opts+=("$arg")
        skip_next=false
        continue
    fi

    case "$arg" in
        --)
            # Everything after -- is the remote command
            remote_cmd+=("$arg")
            ;;
        -*)
            ssh_opts+=("$arg")
            # Check if this option takes a parameter
            flag="${arg#-}"
            # Handle single-char flags (e.g., -o, -i, -p)
            for opt in $opts_with_param; do
                if [[ "$flag" == "$opt" ]]; then
                    skip_next=true
                    break
                fi
            done
            ;;
        *)
            if [ -z "$hostname" ]; then
                hostname="$arg"
            else
                remote_cmd+=("$arg")
            fi
            ;;
    esac
done

if [ -z "$hostname" ]; then
    echo "Error: could not determine hostname from SSH args" >&2
    exit 1
fi

exec gcloud compute ssh \
    --zone "$GCP_ZONE" \
    --project "$GCP_PROJECT" \
    --quiet \
    "$hostname" \
    -- "${ssh_opts[@]}" "${remote_cmd[@]}"
