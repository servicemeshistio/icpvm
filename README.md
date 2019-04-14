# Installation of IBM Cloud Private Community Edition in a single VM

The Community Edition of IBM Cloud Private is free and is a great resource to learn.

Let's walk through the steps to install a single node IBM Cloud Private Cluster

## Prerequisites

* A decent Windows 7 / 10 laptop with minimum 16 GB RAM and Intel Core i7 processor and a preferable minimum 512 GB SSD
* VMWare Workstation 14.1.2/15.0.3 - Even though it is a licensed software, it is worth buying it. The VMware Workstation is a rock solid software.
* You can use `free` VMware player but you can run only one VM per host, which is OK for this environment.
* Build your VM. My personal choice is to use `CentOS` but you can use any Linux distribution of your choice.
* In VMware Workstation, `Edit` ⇨ `Virtual Network Editor` to set the `vmnet8` to subnet address `192.168.142.0` in NAT mode.
* Attach 100 GB thin provisioned disk (vmdk) for storing Docker images and containers

## Download Base VM without ICP

You can download the base VM from [here](#) for the purpose of following through the book. The VM was built using CentOS 7.6 Linux distribution on VMware Workstation 15.0.3. If you prefer your own choice of Linux distribution, build your VM and meet the following prerequisites:

* Install `socat` - For Helm, `socat` is used to set the port forwarding for both the Helm client and Tiller.
  ```
  yum -y install socat
  ```
* Install docker-ce server on your VM
* Example to download docker-ce on CentOS or RHEL system
    ```
    yum install -y yum-utils
    yum-config-manager  --add-repo  https://download.docker.com/linux/centos/docker-ce.repo
    yum -y install docker-ce
    systemctl enable docker
    systemctl start docker
    ```
* The root password is `password` in the base VM and it automatically logs in user `db2psc` for which the password is `password`.

If you want to skip the following IBM Cloud Private Installation procedure, you can download the VM with IBM Cloud Private from this [link](#).

## Resource for VM

You need minimum Intel Core i7 processor on your laptop. Assign 16 GB of RAM and 8 cores to the VM.

The installation requires minimum 8 cores for the Master VM. So, with a Intel Core i7 having only 4 cores, how do we get the extra cores.

If using Intel Core i7 processor in a laptop, it gives 4 cores and 2 threads per core. It is OK to allocate 8 CPU to the VM. The VMware is pretty good in dynamic CPU scheduling.

## Internet Access

Make sure that you can run `ping -c4 google.com` from the VM to make sure that Internet access is available.  

If ping does not succeed, it is quite possible that the network address of VMnet8 adapter needs to be fixed. Refer to [this](docs/vmnet.md) link for instructions to fix vmnet8 subnet address in VMware.

## Install Single Node IBM Cloud Private Kubernetes Cluster

On your VM, login as root and login to your docker account to download the installation docker image.

Login as root
```
su -
```

Login to Dockerhub
```
docker login -u <username> -p <password>
```

Download ICP 3.1.2 installer (At the time of writing this guide, ICP 3.1.2 is the latest version.)

```
docker pull ibmcom/icp-inception:3.1.2
```

The docker pull will begin to download the ICP installer.

```
3.1.2: Pulling from ibmcom/icp-inception
a073c86ecf9e: Pull complete
cbc604ae1944: Downloading [============>                                      ]  18.85MB/74.78MB
650be687acc7: Download complete
a687004334e9: Downloading [=>                                                 ]  9.157MB/380.7MB
7664ea9d19f3: Downloading [========>                                          ]  7.851MB/45.49MB
97c4037e775d: Pulling fs layer
5fb11bea9f19: Waiting
19aea527057b: Waiting
060ae3284742: Waiting
8db2b6e28cb8: Waiting
92a37b9fe585: Waiting
dfb007dce8a8: Waiting
0573abd4b204: Waiting
875ebddb61da: Waiting
a1a7fd214344: Waiting
391862def9ea: Waiting
66ae4853d35e: Waiting
bf0833453156: Waiting
6d3268394639: Waiting
```

### Prepare Hosts file

Extract sample hosts and config.yaml file from the installer and copy private ssh key to the ICP home directory

```
mkdir -p /opt/ibm/icp3.1.2
cd /opt/ibm/icp3.1.2

docker run --rm -v $(pwd):/data -e LICENSE=accept \
   ibmcom/icp-inception:3.1.2 \
   cp -r cluster /data
```

### Set up password less SSH for the root user 

Even though we are using a single VM, we still need password less ssh for the root user.

```
ssh-keygen -f $HOME/.ssh/id_rsa -t rsa -N '' -q
ssh-copy-id -i ~/.ssh/id_rsa.pub root@osc01
```

After above is set up, login as `ssh osc01` and you should be able to login without having to provide password.

The `ssh-copy-id` will prompt for specifying root password for the VM. The hostname of the VM is `osc01` and the root password is `password`.


### Copy ssh key for Ansible install

```
/bin/cp -f ~/.ssh/id_rsa ./cluster/ssh_key
```

Define the topology of the ICP cluster by editing and making changes to the hosts file.

```
cd /opt/ibm/icp3.1.2/cluster
```

Edit file `hosts` to define the topology as per below:

```
[master]
192.168.142.101

[worker]
192.168.142.101

[proxy]
192.168.142.101
```

We are using master, worker and proxy nodes in a single node VM..

### Prepare `config.yaml` file

The `config.yaml` file is the one that controls the installation of the IBM Cloud Private. We can decide the features and functions that we want to include in the install.

The detailed list of configuration parameters are available at this [link](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_3.1.2/installing/config_yaml.html).

We will use the following `config.yaml` file. Copy the following contents to your config.yaml file.

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
default_admin_password: admin
install_docker: false
private_registry_enabled: false
image_repo: ibmcom
offline_pkg_copy_path: /temp
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

### Install IBM Cloud Private

```
cd /opt/ibm/icp3.1.2/cluster
docker run --rm \
   --net=host -t \
   --name=inception \
   -e LICENSE=accept \
   -v $(pwd):/installer/cluster \
   ibmcom/icp-inception:3.1.2 \
   install -vv
```

The Ansible install will begin and it may take anywhere from 20 to 60 minutes to build the IBM Cloud Private Cluster on a single node. The installer will download required docker images from Docker hub for different components. 

If installation fails, look through the message and in most case, this might be due to the slow Internet connection, missing dependencies on OS for some packages, insufficient CPU and/or memory. 

### Troubleshooting Tips

Before installing ICP, make sure to keep the backup of `osdisk.vmdk`. If install fails, just replace `osdisk.vmdk` from the backup. This is the easy method. However, if you know VMware well, you could take the snapshot before starting the install and then revert back in case of a failure.

But, reverting the snapshot will also revert the disk snapshot of the `dockerbackend.vmdk` and we do not want that to happen. Since docker images are downloaded from docker hub, it is best to keep them separate so that the subsequent install do not have to download them again.

The main reason of the install failure is due to insufficient memory / cpu and a slow internet connection. For slow internet connections, it is best to revert the `osdisk.vmdk` from backup so that the downloaded docker images are retained. You will need to poweroff the VM to revert the `osdisk.vmdk`. 

However, you can restart the installation using the same command. To start clean again, you can uninstall the incomplete previous install and then try again. [Note: Do this only when if you are not reverting the `osdisk.vmdk` from the backup].

Uninstall in case you need to restart it again

```
cd /opt/ibm/icp3.1.2/cluster
docker run --rm \
   --net=host -t \
   -e LICENSE=accept \
   -v $(pwd):/installer/cluster \
   ibmcom/icp-inception:3.1.2 \
   uninstall -vv

```

While install is going on, you can login to the `inception` container and run `kubectl` commands to see what is happening. This assumes that you are familiar with the Kubernetes `kubectl` commands.

For example:

Open another GNOME Terminal, login as `root` and run the following command:

```
docker exec -it inception bash
```

After you login to the container, you can run `kubectl` commands.

```
kubectl -n kube-system get pods
```

### After successful install

After Install is done successfully, you will see the URL of the Web Console.

The last few lines of the install output may look like as below:

```
PLAY RECAP *******************************************************************************
192.168.142.101            : ok=157  changed=101  unreachable=0    failed=0   
localhost                  : ok=236  changed=147  unreachable=0    failed=0   
POST DEPLOY MESSAGE **********************************************************************

The Dashboard URL: https://192.168.142.101:8443, default username/password is admin/admin

Playbook run took 0 days, 0 hours, 20 minutes, 38 seconds

```

### Install kubectl

`kubectl` gets installed automatically to `/usr/local/bin`.

Just for reference: You can install `kubectl` on the guest VM from the inception container.

```
cd /opt/ibm/icp3.1.2/cluster
docker run --rm -v $(pwd):/data -e LICENSE=accept \
   ibmcom/icp-inception:3.1.2 \
   cp -r /usr/local/bin/kubectl /data

chmod +x kubectl
cp kubectl /bin

```

### Install cloudctl and helm client

 The `cloudctl` tool is the superset of cloud foundry tool to run command line tools to authenticate with IBM Cloud Private so that helm install can be done using `mTLS`. Their are many other capabilities of `cloudctl`.

`cloudctl` gets installed automatically to `/usr/local/bin`.

Just for reference: You can get `cloudctl` from inception container.

```
MASTERNODE=192.168.142.101
curl -kLo /tmp/helm-linux-amd64-v2.9.1.tar.gz https://$MASTERNODE:8443/api/cli/helm-linux-amd64.tar.gz
curl -kLo /tmp/cloudctl-linux-amd64-3.1.0-715 https://$MASTERNODE:8443/api/cli/cloudctl-linux-amd64
mv /tmp/cloudctl-linux-amd64-3.1.0-715 /bin/cloudctl
chmod +x /bin/cloudctl
tar xvfz /tmp/helm-linux-amd64-v2.9.1.tar.gz -C /tmp linux-amd64/helm
mv /tmp/linux-amd64/helm /bin
chmod +x /bin/helm
```

### Authenticate using cloudctl

```
MASTERNODE=192.168.142.101
CLUSTERNAME=servicemesh
cloudctl login -n kube-system -u admin -p admin -a https://$MASTERNODE:8443 --skip-ssl-validation -c "id-$CLUSTERNAME-account"
```

After the above command is run, it will set the context for the `kubectl` command to authenticate to the IBM Cloud Private cluster. It will create `~/.kube` and create the context.

The sample output from the above command will be:

```
Authenticating...
OK

Targeted account servicemesh Account (id-servicemesh-account)

Targeted namespace kube-system

Configuring kubectl ...
Property "clusters.servicemesh" unset.
Property "users.servicemesh-user" unset.
Property "contexts.servicemesh-context" unset.
Cluster "servicemesh" set.
User "servicemesh-user" set.
Context "servicemesh-context" created.
Switched to context "servicemesh-context".
OK

Configuring helm: /root/.helm
OK
```  

After above, you can run `kubectl` commands.

For example:
```
# kubectl -n kube-system get nodes -o wide
NAME              STATUS    ROLES                                 AGE       VERSION       INTERNAL-IP       EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION              CONTAINER-RUNTIME
192.168.142.101   Ready     etcd,management,master,proxy,worker   32m       v1.11.5+icp   192.168.142.101   <none>        CentOS Linux 7 (Core)   3.10.0-957.5.1.el7.x86_64   docker://18.9.1
```

> Remember: After you login to the ICP cluster using `cloudctl` login command, an authentication token is generated which is valid only for 12 hours. After expiry of the token, you will need to run the `cloudctl login` command.

### Non-expiring Login

If we authenticate using certificates, we can eliminate 12 hour limit. We can do this by using a different home for kubectl config.

Here is an example:

```
MASTERNODE=192.168.142.101
ICP_HOMEDIR=/opt/ibm/icp3.1.2
MYKUBE=$HOME/.mykube
export KUBECONFIG=$MYKUBE/config
mkdir -p $MYKUBE/conf
sudo cp $ICP_HOMEDIR/cluster/cfc-certs/kubernetes/kubecfg.key $MYKUBE/conf
sudo cp $ICP_HOMEDIR/cluster/cfc-certs/kubernetes/kubecfg.crt $MYKUBE/conf
sudo chown -R $(echo $(id -u)).$(echo $(id -g)) $MYKUBE/conf
cat << EOF > $MYKUBE/config
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$MASTERNODE:8001
  name: servicemesh
contexts:
- context:
    cluster: servicemesh
    namespace: default
    user: $DEFAULTUSERNAME
  name: servicemesh
current-context: servicemesh
users:
- name: $DEFAULTUSERNAME
  user:
    client-certificate: $MYKUBE/conf/kubecfg.crt
    client-key: $MYKUBE/conf/kubecfg.key
EOF
```

After we create a different home dir for `kubeconfig`, we can set the context to this.

```
MYKUBE=$HOME/.mykube
export KUBECONFIG=$MYKUBE/config
kubectl config use-context servicemesh
```

Now, we can run `kubectl` command which will not expire as we are using certificate based authentication, which was the case `cloudctl login` but that comes with a bearer token.

This method is good if we work directly from the server.

### Set context and change context

While typing many `kubectl` commands, we need to work in a specific namespace and that requires setting `-n <namespaceName>` in every command. The default namespace is `default` but that can be changed easily. 

Copy these two functions in your `.bashrc` file to set context and change context.

```
function sc ()
{
  N=$1
  shift
  kubectl config set-context $(kubectl config current-context) --namespace=$N
  export PS1="\[\e[1;32m\][\u@\h $(cs)\W]#\[\033[00m\] "
}

function cs ()
{
  CC=$(kubectl config current-context)
  NS=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CC\")].context.namespace}")
  export PS1="\[\e[1;32m\][\u@\h ($NS)\W]#\[\033[00m\] "
  echo "($NS)"
}
```

### Launch IBM Cloud Private Web UI

Open URL https://192.168.142.101:8443 from a browser. My personal choice is Google Chrome.

Use user id `admin` and password `admin`.

This will show the web UI of the IBM Cloud Private. Go through this to familiarize yourself.

Click `Catalog` to see the number of open source helm charts that you can install in this IBM Cloud Private Kubernetes cluster. 

### Turn-off some non-essential daemonsets and deployments to conserve resources

Note: When we specify `logging` false in `config.yaml` file, `audit-logging-fluentd-ds` still does not get disabled.

Just for reference:

Run the following commands to turn off some daemonsets and deployments that we do not require.

```
echo Put label switch=up on this node
kubectl label node $(hostname -i) switch=up --overwrite

echo Patch daemonsets with label switch=down 
kubectl -n kube-system patch ds logging-elk-filebeat-ds  --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "switch": "down" } } } } }'
kubectl -n kube-system patch ds nvidia-device-plugin  --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "switch": "down" } } } } }'
kubectl -n kube-system patch ds audit-logging-fluentd-ds  --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "switch": "down" } } } } }'

echo set replicas=0 for deployments
kubectl -n kube-system scale deploy logging-elk-client --replicas=0
kubectl -n kube-system scale deploy logging-elk-kibana --replicas=0
kubectl -n kube-system scale deploy logging-elk-logstash --replicas=0
kubectl -n kube-system scale deploy logging-elk-master --replicas=0
kubectl -n kube-system scale deploy secret-watcher --replicas=0
```

In case, the ds and deployments need to start. We can run the following commands to start them. [Note: Just for reference - do not run.]

```
  kubectl -n kube-system patch ds logging-elk-filebeat-ds --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "switch": "up" } } } } }'
  kubectl -n kube-system patch ds nvidia-device-plugin  --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "switch": "up" } } } } }'
  kubectl -n kube-system patch ds audit-logging-fluentd-ds  --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "switch": "up" } } } } }'

  kubectl -n kube-system scale deploy logging-elk-client --replicas=1
  kubectl -n kube-system scale deploy logging-elk-kibana --replicas=1
  kubectl -n kube-system scale deploy logging-elk-logstash --replicas=1
  kubectl -n kube-system scale deploy logging-elk-master --replicas=1
  kubectl -n kube-system scale deploy secret-watcher --replicas=1
```

## Turn-off nginx-ingress-controller daemonset

Let's turn off `nginx-ingress-controller` that comes with IBM Cloud Private.

```
echo Shutdown nginx-ingress-controller with changing proxy to false 
kubectl -n kube-system patch ds nginx-ingress-controller  --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "proxy": "false" } } } } }'
```

In case, you need  to turn on `nginx-ingress-controller`, you can run the following command:

```
echo Shutdown nginx-ingress-controller with changing proxy to true 
kubectl -n kube-system patch ds nginx-ingress-controller  --patch '{ "spec": { "template": { "spec": { "nodeSelector": { "proxy": "true" } } } } }'
```

The alternative method is to edit the daemon set using `vi` and then change the label proxy from true to false or false to true.

```
kubectl -n kube-system edit ds nginx-ingress-controller
```

The definition of `ds` `nginx-ingress-controller` will open in a `vi` editor and you can edit the proxy field to either `true` or `false`.

Example:

```
      nodeSelector:
        proxy: "false"
```

## Download VM with ICP Installed

If you want to skip the IBM Cloud Private Installation procedure, you can download the VM with IBM Cloud Private from this [link](#).

## Install Bookinfo Microservice Application from Istio

We will install a sample Microservice application in IBM Cloud Private environment.

The sample application is available at https://istio.io/docs/examples/bookinfo/

### Create name space

We will install this application in a namespace `istio-lab`. Create the name space as follows:

```
kubectl create namespace istio-lab
```

### Grant cluster admin role to the name space

```
echo Create cluster role binding

cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: istio-lab-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts:istio-lab
EOF
```

### Create image policy to download docker images from docker.io

```
echo Create image policy to download docker images from docker.io/*
kubectl create -f - << EOF
apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
kind: ClusterImagePolicy
metadata:
  name: docker-image-policy
spec:
  repositories:
  - name: docker.io/*
    policy:
      va:
        enabled: false
EOF
```

### Create image policy to download docker images from quay.io

```
echo Create image policy to download docker images from quio.io/*
kubectl create -f - << EOF
apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
kind: ClusterImagePolicy
metadata:
  name: quay-image-policy
spec:
  repositories:
  - name: quay.io/*
    policy:
      va:
        enabled: false
EOF
```

### Download Bookinfo YAML 

```
curl -L https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -o bookinfo.yaml
```

### Install Bookinfo Microservice application

```
kubectl -n istio-lab apply -f bookinfo.yaml
```

The docker images will be downloaded from the `docker.io/istio/*`

Check progress of the Microservice application deployment

```
# kubectl -n istio-lab get pods
NAME                             READY     STATUS              RESTARTS   AGE
details-v1-756886897d-7f9fs      0/1       ContainerCreating   0          11s
productpage-v1-8fcdcb496-6brcx   0/1       ContainerCreating   0          8s
ratings-v1-7fc6ccbbbb-sfm9q      0/1       ContainerCreating   0          11s
reviews-v1-59ff68c6cf-qhht7      0/1       ContainerCreating   0          11s
reviews-v2-58f7dbbf8c-44mn7      0/1       ContainerCreating   0          10s
reviews-v3-654d6f5b95-xz4zl      0/1       ContainerCreating   0          9s
```

After a while, all micro services should be up and running.

```
# kubectl -n istio-lab get pods
NAME                             READY     STATUS    RESTARTS   AGE
details-v1-756886897d-7f9fs      1/1       Running   0          4m
productpage-v1-8fcdcb496-6brcx   1/1       Running   0          4m
ratings-v1-7fc6ccbbbb-sfm9q      1/1       Running   0          4m
reviews-v1-59ff68c6cf-qhht7      1/1       Running   0          4m
reviews-v2-58f7dbbf8c-44mn7      1/1       Running   0          4m
reviews-v3-654d6f5b95-xz4zl      1/1       Running   0          4m
```

## Install Booksapp Microservice Application from Linkerd

We will install a sample Microservice application in IBM Cloud Private environment for Linkerd.

The sample application is available at https://github.com/BuoyantIO/booksapp

### Create name space

We will install this application in a namespace `linkerd-lab`. Create the name space as follows:

```
kubectl create namespace linkerd-lab
```

### Grant cluster admin role to the name space

```
echo Create cluster role binding

cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: linkerd-lab-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts:linkerd-lab
EOF
```

### Create image policy to download docker images from docker.io/istio

```
echo Create image policy to download docker images from docker.io/buoyant
kubectl create -f - << EOF
apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
kind: ClusterImagePolicy
metadata:
  name: linkerd-lab-image-policy
spec:
  repositories:
  - name: docker.io/buoyantio*
    policy:
      va:
        enabled: false
EOF
```

### Download Booksapp Microservice from Linkerd.io

```
curl -L https://run.linkerd.io/booksapp.yml -o booksapp.yaml
```

### Install Booksapp Microservice application from Linkerd

```
kubectl -n linkerd-lab apply -f booksapp.yaml
```

The docker images will be downloaded from the `docker.io/buoyantio/*`

Check progress of the Microservice application deployment from linkerd

```
# kubectl -n linkerd-lab get pods
NAME                      READY     STATUS    RESTARTS   AGE
authors-57dfdd8cc-5dlvd   1/1       Running   0          57s
books-579b4d84cc-bhw95    1/1       Running   0          57s
traffic-8bf9fb6b-kl9xk    1/1       Running   0          56s
webapp-84478cc85c-gbcj4   1/1       Running   0          57s
webapp-84478cc85c-kwbrw   1/1       Running   0          57s
webapp-84478cc85c-pgb6g   1/1       Running   0          57s
```

## Troubleshooting

After you shutdown VM and restart again, `kubectl -n kube-system get pods` or other `kubectl` command fails with the follwoing message.

```
[root@osc01 ~]# kubectl -n kube-system get pods
error: the server doesn't have a resource type "pods"
```

This is due to the fact that proper kubectl context is not set properly after VM was restarted.

You can fix this by running the following commands.

```
export KUBECONFIG=/root/.mykube/config
kubectl config use-context servicemesh
```

After proper contexts are set, you can run `kubectl` commands.
