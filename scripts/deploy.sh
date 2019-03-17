#!/bin/bash

set -e

if [ -f /usr/local/bin/kubectl ] ; then
  MYKUBE=$HOME/.mykube
  export KUBECONFIG=$MYKUBE/config
  kubectl config use-context servicemesh
fi

logger $(date) : Replacing certificates for ICP

echo =========================================
echo Move old certificate to /tmp
cd /opt/ibm/icp3.1.2/cluster/cfc-certs/router
/bin/mv icp-router.key /tmp
/bin/mv icp-router.crt /tmp
echo =========================================
echo Copy new certificates
/bin/cp /etc/letsencrypt/live/icp.zinox.com/privkey.pem icp-router.key
/bin/cp /etc/letsencrypt/live/icp.zinox.com/cert.pem icp-router.crt
echo =========================================
echo Generate PEM from the key
openssl rsa -in icp-router.key -outform pem > icp-router-key.pem
/bin/mv -f icp-router-key.pem icp-router.key
echo =========================================
echo Create new secret
cd /opt/ibm/icp3.1.2/cluster/cfc-certs/router
kubectl -n kube-system delete secret router-certs
kubectl -n kube-system create secret tls router-certs --cert=icp-router.crt --key=icp-router-key.pem
echo =========================================
echo Delete icp-management pod
kubectl -n kube-system delete pod $(echo $(kubectl -n kube-system get pods --no-headers | grep icp-management | awk '{print $1}'))
echo =========================================
echo Replace docker private registry certificate
cd /etc/docker/certs.d/icp.zinox.com\:8500/
/bin/cp /opt/ibm/icp3.1.2/cluster/cfc-certs/router/icp-router.crt ca.crt
echo =========================================
echo Restart docker private registry
kubectl delete pods -n kube-system image-manager-0
echo =========================================
