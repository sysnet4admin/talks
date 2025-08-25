#!/usr/bin/env bash

##### Addtional configuration for All-in-one >> replace to extra-k8s-pkgs
EXTRA_PKGS_ADDR="https://raw.githubusercontent.com/sysnet4admin/IaC/main/k8s/extra-pkgs/v1.32"

# deploy nfs-provisioner & storageclass as default 
curl -sSL "$EXTRA_PKGS_ADDR/nfs_exporter.sh" | bash -s dynamic-vol
kubectl create -f $EXTRA_PKGS_ADDR/nfs-provisioner-v4.0.2.yaml
kubectl create -f $EXTRA_PKGS_ADDR/storageclass.yaml
kubectl annotate storageclass managed-nfs-storage storageclass.kubernetes.io/is-default-class=true

# nfs change from default to nfs-provisioner ns 
kubectl create namespace nfs-provisioner
kubectl get serviceaccount nfs-client-provisioner -n default -o yaml | \
sed 's/namespace: default/namespace: nfs-provisioner/' | \
kubectl apply -f -
kubectl get deployment nfs-client-provisioner -n default -o yaml | \
sed 's/namespace: default/namespace: nfs-provisioner/' | \
kubectl apply -f -
kubectl rollout restart deployment nfs-client-provisioner -n nfs-provisioner
kubectl delete deployment nfs-client-provisioner -n default
kubectl delete serviceaccount nfs-client-provisioner -n default

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
curl -sSL "$EXTRA_PKGS_ADDR/get_helm_v3.17.1.sh" | bash 
helm repo add edu https://k8s-edu.github.io/Bkv2_main/helm-charts/

# helm completion on bash-completion dir & alias+
helm completion bash > /etc/bash_completion.d/helm
echo 'alias h=helm' >> ~/.bashrc
echo 'complete -F __start_helm h' >> ~/.bashrc


