# Set up Private Registry on ICP

ICP has iws own private registry that runs on port 8500. This registry gets created during ICP install.

Just added one independent registry and I have to make the following changes.

## Stop image-manager statefulset

```
kubectl -n kube-system edit sts image-manager
```

Edit replicas=0 so that the ICP local registry is stopped.

## Stop nginx-ingress-controller

The nginx ingress controller controls the traffic. I had to shut this down to allow public registry to run on a host in addition to ICP. There must be ways to make ICP registry working with public but I did not explore this.

```
kubectl -n kube-system edit ds nginx-ingress-controller
```

Search for `proxy` and change `true` to `false`. By changing the node selector label `proxy` to false, this daemon set will stop running.

## Build registry

Attach a 300 GB LUN to the VM and format it as xfs and mount this to `/var/lib/registry`

```
1. Clear all chains:
# iptables -t filter -F
# iptables -t filter -X
2. restart Docker Service:
# systemctl restart docker
```

## Create certificates

Consult [letsencrypt](letsencrypt.md) for creating certificates for the docker registry

```
  cd /etc/letsencrypt/live/icp.zinox.com
  /bin/cp -f privkey.pem domain.key
  cat cert.pem chain.pem > domain.crt
  chmod 600 domain.*
```

Change `icp.zinox.com` with your domain name.

## Create a registry user

```
  mkdir -p /registry/auth
  docker run --rm --entrypoint htpasswd registry:2 -Bbn ibmuser StrongPassw0rd  > /registry/auth/htpasswd
```

## Run a registry

```
REGISTRY_DOMAIN=icp.zinox.com

docker run -d --name registry --restart=always \
  -p 443:5000 \
  -v /etc/letsencrypt/live/icp.zinox.com:/certs \
  -v /var/lib/registry:/var/lib/registry \
  -v /registry/auth:/auth \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_HTTP_HOST=https://${REGISTRY_DOMAIN} \
  -e REGISTRY_AUTH_HTPASSWD_REALM=${REGISTRY_DOMAIN} \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

```

Change `icp.zinox.com` with your domain name.


## Login to the registry

```
docker login -u ibmuser icp.zinox.com
```

Change `icp.zinox.com` with your domain name.

## tag and push image

```
docker tag registry:2 icp.zinox.com/registry:2
docker push icp.zinox.com/registry:2
```

## List registry

```
curl https://ibmuser:StringPassw0rd@icp.zinox.com/v2/_catalog

{"repositories":["registry"]}
```

