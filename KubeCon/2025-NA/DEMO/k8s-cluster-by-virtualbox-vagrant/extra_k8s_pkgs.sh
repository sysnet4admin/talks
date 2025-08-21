#!/usr/bin/env bash

##### Addtional configuration for All-in-one >> replace to extra-k8s-pkgs
EXTRA_PKGS_ADDR="https://raw.githubusercontent.com/sysnet4admin/IaC/main/k8s/extra-pkgs/v1.32"

# deploy nfs-provisioner & storageclass as default 
sh -c "$EXTRA_PKGS_ADDR/nfs_exporter.sh dynamic-vol"
kubectl create -f $EXTRA_PKGS_ADDR/nfs-provisioner-v4.0.2.yaml
kubectl create -f $EXTRA_PKGS_ADDR/storageclass.yaml
kubectl annotate storageclass managed-nfs-storage storageclass.kubernetes.io/is-default-class=true

# config cilium layer2 mode 
# split cilium CRD due to it cannot apply at once. 
# it looks like Operator limitation
# QA: 
# - 300sec can deploy but safety range is from 540 - 600 

# config cilium layer2 mode 
(sleep 540 && kubectl apply -f $EXTRA_PKGS_ADDR/cilium-l2mode.yaml)&
# config cilium ip range and it cannot deploy now due to CRD cannot create yet 
(sleep 600 && kubectl apply -f $EXTRA_PKGS_ADDR/cilium-iprange.yaml)&

# install helm & add repo 
sh -c "$EXTRA_PKGS_ADDR/get_helm_v3.17.1.sh"
helm repo add edu https://k8s-edu.github.io/Bkv2_main/helm-charts/

# helm completion on bash-completion dir & alias+
helm completion bash > /etc/bash_completion.d/helm
echo 'alias h=helm' >> ~/.bashrc
echo 'complete -F __start_helm h' >> ~/.bashrc
