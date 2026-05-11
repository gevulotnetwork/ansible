#!/bin/bash
# Ansible SSH wrapper for GCP instances
#
# Uses gcloud to set up a ControlMaster SSH connection on first use,
# then reuses it for subsequent calls (avoiding gcloud overhead per task).

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
            remote_cmd+=("$arg")
            ;;
        -*)
            ssh_opts+=("$arg")
            flag="${arg#-}"
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

# Persistent ControlMaster socket per host
SOCKET_DIR="/tmp/gcloud-ssh-sockets"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/$hostname"

# If a ControlMaster socket already exists and is alive, use plain ssh
if ssh -O check -S "$SOCKET" "$hostname" 2>/dev/null; then
    exec ssh -S "$SOCKET" "${ssh_opts[@]}" "$hostname" "${remote_cmd[@]}"
fi

# No active socket — use gcloud to establish a ControlMaster connection
# First call: gcloud sets up the connection and leaves a persistent socket
gcloud compute ssh \
    --zone "$GCP_ZONE" \
    --project "$GCP_PROJECT" \
    --quiet \
    "$hostname" \
    -- -o "ControlMaster=auto" \
       -o "ControlPath=$SOCKET" \
       -o "ControlPersist=600" \
       "${ssh_opts[@]}" "${remote_cmd[@]}"
