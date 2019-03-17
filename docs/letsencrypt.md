# Use letsencrypt certificates

## Install certbot

```
yum -y install epel-release
yum -y install certbot 
```

## Get Letsencrypt Certifcate

Since we are using IBM Cloud Private, we need a manual way to obtain certificates

<pre>
# <b>certbot certonly --manual --server https://acme-v02.api.letsencrypt.org/directory --preferred-challenges dns</b>

Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator manual, Installer None
Starting new HTTPS connection (1): acme-v02.api.letsencrypt.org
Please enter in your domain name(s) (comma and/or space separated)  (Enter 'c'
to cancel): icp.zinox.com
Obtaining a new certificate
Performing the following challenges:
dns-01 challenge for icp.zinox.com
 
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
NOTE: The IP of this machine will be publicly logged as having requested this
certificate. If you're running certbot in manual mode on a machine that is not
your server, please ensure you're okay with that.
 
Are you OK with your IP being logged?
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o: Y
 
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please deploy a DNS TXT record under the name
_acme-challenge.icp.zinox.com with the following value:
 
p1QJMAqecEXuh__Wc-ujCjyQkv1NVwsBmEc8ojm9uPw
</pre>

Here add the txt record in your domain provider for the CN. In our case, the CN is `icp.zinox.com` and verify it is available before going to the next step. 

### Open another command line window.

Test if the TXT record is available before going to the next step in the previous window. ]
 
```
$ dig -t txt +short _acme-challenge.icp.zinox.com @ns1131.dns.dyn.com
```

The output should match with the TXT record that you had specified in your TXT record through your domain provider.

Make sure that DNS txt record is available.

### Switch back to the previous window.

``` 
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Press Enter to Continue
Waiting for verification...
Cleaning up challenges
 
IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/icp.zinox.com/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/icp.zinox.com/privkey.pem
   Your cert will expire on 2018-11-30. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot
   again. To non-interactively renew *all* of your certificates, run
   "certbot renew"
 - If you like Certbot, please consider supporting our work by:
 
   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

```

## Use Letsencrypt certificate with ICP

Create `cfc-certs/router` directory in `cluster` directory.


Change `icp.zinox.com` to your domain name.

```
mkdir -p /opt/ibm/icp3.1.2/cluster/cfc-certs/router
cd /opt/ibm/icp3.1.2/cluster/cfc-certs/router
cp /etc/letsencrypt/live/icp.zinox.com/privkey.pem icp-router.key
cp /etc/letsencrypt/live/icp.zinox.com/cert.pem icp-router.crt
file icp-router.key
```

IBM Cloud Private expects `icp-router.key` in the PEM format even though the letsencrypt names it with pem extension. Run file command on `privkey.pem` and it will show as a TXT file and not as PEM format.

### Convert key to PEM

```
openssl rsa -in icp-router.key -outform pem > icp-router-key.pem
mv icp-router-key.pem icp-router.key
file icp-router.key
```

The file command should show `icp-router.key` as a PEM format.

## Use BYOK Certificates in your new install

Slight changes in the `config.yaml` for using BYOK

```
wait_for_timeout: 600
skip_pre_check: true
firewall_enabled: false
auditlog_enabled: false
federation_enabled: false
secure_connection_enabled: false
network_type: calico
network_cidr: 10.1.0.0/16
service_cluster_ip_range: 10.0.0.1/24
kubelet_extra_args: ["--fail-swap-on=false"]
cluster_name: servicemesh
default_admin_user: admin
default_admin_password: SuperComplexPassw0rd
install_docker: false
private_registry_enabled: false
image_repo: ibmcom
offline_pkg_copy_path: /temp
ansible_port: 44022
cluster_CA_domain: icp.zinox.com
password_rules:
 - '(.*)'
management_services:
 istio: disabled
 vulnerability-advisor: disabled
 storage-glusterfs: disabled
 storage-minio: disabled
 image-security-enforcement: enabled
 metering: disabled
 logging: disabled
 monitoring: disabled
 service-catalog: disabled
 custom-metrics-adapter: disabled
```

Since we are using our own certificate, we need to set the CN using `cluster_CA_domain: <YOUR CN>`

## Use BYOK Certificates in your existing install

In an existing ICP install, the procedure is almost similar.

Change `icp.zinox.com` to your domain name.

```
cd /opt/ibm/icp3.1.2/cluster/cfc-certs/router
mv icp-router.key /tmp
mv icp-router.crt /tmp
cp /etc/letsencrypt/live/icp.zinox.com/privkey.pem icp-router.key
cp /etc/letsencrypt/live/icp.zinox.com/cert.pem icp-router.crt
file icp-router.key
```

### Convert key to PEM

```
openssl rsa -in icp-router.key -outform pem > icp-router-key.pem
mv icp-router-key.pem icp-router.key
file icp-router.key
```

### Restart icp-management pod with new secret

```
cd /opt/ibm/icp3.1.2/cluster/cfc-certs/router
kubectl -n kube-system delete secret router-certs
kubectl -n kube-system create secret tls router-certs --cert=icp-router.crt --key=icp-router-key.pem
kubectl -n kube-system delete pod $(echo $(kubectl -n kube-system get pods --no-headers | grep icp-management | awk '{print $1}'))
```

### Restart ICP docker registry

```
cd /etc/docker/certs.d/icp.zinox.com\:8500/
cp /opt/ibm/icp3.1.2/cluster/cfc-certs/router/icp-router.crt ca.crt
kubectl delete pods -n kube-system image-manager-0
```

### Login to the Docker Local Registry

```
docker login icp.zinox.com:8500 -u icpadmin
```

## Renew Letsencrypt Certificates

Run [cron](../scripts/cron.sh) job with a [deploy](../scripts/deploy.sh) script.

### Cron job

```
cat <<EOF > /etc/cron.d/letencrypt
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
30 2 * * * root /usr/bin/certbot renew --deploy-hook /root/bin/letsencrypt/deploy.sh
EOF
```

### Deply Script

```
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

```