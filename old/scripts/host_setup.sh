#!/usr/bin/env bash

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

ansible-galaxy role install -r roles/requirements.yml

ansible-playbook main.yml
pipx install --include-deps ansible

python3 -m venv /root/ansible
/root/ansible/bin/pip install -r /root/requirements.txt
