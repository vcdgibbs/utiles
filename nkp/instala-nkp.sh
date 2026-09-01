#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Proporcionar el archivo de variables de ambiente."
    exit 1
fi

if ! [ -f $1 ]; then
    echo "Archivo $1 no se encuentra."
    exit 1
fi

source $1

nkp create cluster nutanix \
--self-managed \
--insecure \
\
--cluster-name=${CLUSTER_NAME} \
--endpoint=${NUTANIX_ENDPOINT} \
--control-plane-endpoint-ip=${CONTROLPLANE_IP} \
--control-plane-external-endpoint=${CONTROLPLANE_EXTERNAL_ENDPOINT_FLAG} \
--csi-storage-container=${STORAGE_CONTAINER_NAME} \
--kubernetes-service-load-balancer-ip-range=${SERVICE_LB_IP_RANGE} \
\
--control-plane-prism-element-cluster=${NUTANIX_CLUSTER} \
--control-plane-subnets=${SUBNET} \
--control-plane-vm-image=${VM_IMAGE} \
--control-plane-replicas=3 \
\
--worker-prism-element-cluster=${NUTANIX_CLUSTER} \
--worker-subnets=${SUBNET} \
--worker-vm-image=${VM_IMAGE} \
--worker-replicas=4 \
--ssh-public-key-file=${SSH_PUBLIC_KEY} \
\
${NTP_FLAGS} \
${BUNDLE_FLAGS}
