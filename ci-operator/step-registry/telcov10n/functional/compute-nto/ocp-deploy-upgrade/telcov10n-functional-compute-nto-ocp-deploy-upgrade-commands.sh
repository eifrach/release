#!/bin/bash
set -e
set -o pipefail
set -x
MOUNTED_HOST_INVENTORY="/var/host_variables"

process_inventory() {
    local directory="$1"
    local dest_file="$2"

    if [ -z "$directory" ]; then
        echo "Usage: process_inventory <directory> <dest_file>"
        return 1
    fi

    if [ ! -d "$directory" ]; then
        echo "Error: '$directory' is not a valid directory"
        return 1
    fi

    find "$directory" -type f | while IFS= read -r filename; do
        if [[ $filename == *"secretsync-vault-source-path"* ]]; then
          continue
        else
          echo "$(basename "${filename}")": \'"$(cat "$filename")"\'
        fi
    done > "${dest_file}"

    echo "Processing complete. Check \"${dest_file}\""
}

main() {

    echo "Set CLUSTER_NAME env var"
    if [[ -f "${SHARED_DIR}/cluster_name" ]]; then
        CLUSTER_NAME=$(cat "${SHARED_DIR}/cluster_name")
    fi
    export CLUSTER_NAME=${CLUSTER_NAME}
    echo CLUSTER_NAME="${CLUSTER_NAME}"

    echo "Create group_vars directory"
    mkdir -pv /eco-ci-cd/inventories/ocp-deployment/group_vars

    find /var/group_variables/common/ -mindepth 1 -type d | while read -r dir; do
        echo "Process group inventory file: ${dir}"
        process_inventory "$dir" /eco-ci-cd/inventories/ocp-deployment/group_vars/"$(basename "${dir}")"
    done

    find /var/group_variables/"${CLUSTER_NAME}"/ -mindepth 1 -type d | while read -r dir; do
        echo "Process group inventory file: ${dir}"
        process_inventory "$dir" /eco-ci-cd/inventories/ocp-deployment/group_vars/"$(basename "${dir}")"
    done

    echo "Create host_vars directory"
    mkdir -pv /eco-ci-cd/inventories/ocp-deployment/host_vars

    mkdir -pv /tmp/"${CLUSTER_NAME}"
    cp -r "${MOUNTED_HOST_INVENTORY}/${CLUSTER_NAME}/hypervisor" /tmp/"${CLUSTER_NAME}"/hypervisor
    cp -r "${MOUNTED_HOST_INVENTORY}/${CLUSTER_NAME}/"* /tmp/"${CLUSTER_NAME}"/
    ls -l /tmp/"${CLUSTER_NAME}"/
    MOUNTED_HOST_INVENTORY="/tmp"

    find ${MOUNTED_HOST_INVENTORY}/"${CLUSTER_NAME}"/ -mindepth 1 -type d | while read -r dir; do
        echo "Process group inventory file: ${dir}"
        process_inventory "$dir" /eco-ci-cd/inventories/ocp-deployment/host_vars/"$(basename "${dir}")"
    done


echo "NTO Configuration Environment Variables:"
echo "  CONTAINER_RUNTIME=${CONTAINER_RUNTIME}"
echo "  RT_KERNEL=${RT_KERNEL}"
echo "  HUGEPAGES_DEFAULT_SIZE=${HUGEPAGES_DEFAULT_SIZE}"
echo "  HUGEPAGES_PAGES=${HUGEPAGES_PAGES}"
echo "  HIGH_POWER_CONSUMPTION=${HIGH_POWER_CONSUMPTION}"
echo "  PER_POD_POWER_MANAGEMENT=${PER_POD_POWER_MANAGEMENT}"
echo "  LABEL_FILTER=${LABEL_FILTER}"


# Prepare extra variables for ansible playbook
# OCP configuration variables
EXTRA_VARS="kubeconfig=/home/telcov10n/project/generated/${CLUSTER_NAME}/auth/kubeconfig"
# NTO Cluster configuration variables
EXTRA_VARS="${EXTRA_VARS} container_runtime=${CONTAINER_RUNTIME}"
EXTRA_VARS="${EXTRA_VARS} rt_kernel=${RT_KERNEL}"
EXTRA_VARS="${EXTRA_VARS} high_power_consumption=${HIGH_POWER_CONSUMPTION}"
EXTRA_VARS="${EXTRA_VARS} per_pod_power_management=${PER_POD_POWER_MANAGEMENT}"
EXTRA_VARS="${EXTRA_VARS} artifacts_folder=${ARTIFACT_DIR}"


# Handle hugepages configuration
if [[ "${HUGEPAGES_PAGES}" != "[]" && -n "${HUGEPAGES_PAGES}" ]]; then
    EXTRA_VARS="${EXTRA_VARS} hugepages='{\"size\": \"${HUGEPAGES_DEFAULT_SIZE}\", \"pages\": ${HUGEPAGES_PAGES}}'"
else
    EXTRA_VARS="${EXTRA_VARS} hugepages='{\"size\": \"${HUGEPAGES_DEFAULT_SIZE}\"}'"
fi

    cd /eco-ci-cd

    echo "Clean old clusters"
    ansible-playbook ./playbooks/compute/delete_old_clusters.yml \
        -i ./inventories/ocp-deployment/build-inventory.py

    echo "Deploy SNO OCP for compute-nto testing"
    ansible-playbook ./playbooks/cluster_upgrade.yml \
        -i ./inventories/ocp-deployment/build-inventory.py \
        --extra-vars "${EXTRA_VARS}"

    echo "Store inventory in SHARED_DIR"
    cp -r /eco-ci-cd/inventories/ocp-deployment/host_vars/* "${SHARED_DIR}"/
    cp -r /eco-ci-cd/inventories/ocp-deployment/group_vars/* "${SHARED_DIR}"/
}

main
