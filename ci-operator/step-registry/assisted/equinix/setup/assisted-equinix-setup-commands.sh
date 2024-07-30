#!/bin/bash

set -x
set -o nounset
set -o errexit
set -o pipefail

echo "************  assisted equinix setup command ************"

# TODO: Remove once OpenShift CI supports it out of the box (see https://access.redhat.com/articles/4859371)
fix_uid.sh

# Fix for issues with DNF and ansible core 2.17 on RHEL8 / RHEL9 systems
pip install ansible==9.8

cd "${ANSIBLE_PLAYBOOK_DIRECTORY}"
ansible-playbook --extra-vars "@vars/ci.yml" \
                 --extra-vars "@vars/ci_equinix_infrastucture.yml" \
                 --extra-vars "${ANSIBLE_EXTRA_VARS}" \
                 "${ANSIBLE_PLAYBOOK_CREATE_INFRA}"
