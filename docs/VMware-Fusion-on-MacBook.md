# Changes in VMware Fusion on Apple MacBook

You need to have minimum VMware Fusion 11.0.2 Professional Edition on your Apple MacBook.

## Changes in configuration for the standalone ICP VM

In our standalone VM for IBM Cloud Private, we are using NAT networking using `vmnet8` having a subnet `192.168.142.0` - which is different than the default values. Without making these changes, you will not be able to access the Internet from inside the VM.

Open a command line shell on your MacBook and run following commands.

```
$ sudo su - <type your password>

# vi /Library/Preferences/VMware\ Fusion/networking
```

Modify line having `VMNET_8_HOSTONLY_SUBNET` to `anwwer VMNET_8_HOSTONLY_SUBNET 192.168.142.0` so that it matches with the `vmnet8` address that we are using inside the VM.

### Fix Gateway for vmnet8

Modify file `/Library/Preferences/VMware\ Fusion/vmnet8`

```
# cd /Library/Preferences/VMware\ Fusion/vmnet8
# vi nat.conf
```

And change `ip` and `netmask` after comment `# NAT gateway address`

```
ip = 192.168.142.2
netmask = 255.255.255.0
```

### Restart the network

```
# cd /Applications/VMware\ Fusion.app/Contents/Library/

# vmnet-cli --configure
# vmnet-cli --stop
# vmnet-cli --start
```

From <https://kb.vmware.com/s/article/1026510> 

## Change Memory and CPU

Your MacBook must have minimum 16 GB RAM.

Lanuch VMware Fusion App and go to menu `Virtual Machine` > `Settings` and select `Processors and Memory`.

Modify CPU processors to 6 Processor core and change memory to 12288 MB.

## Start VM

After making above changes, run the VM.

### Set Context 

Give the VM few minutes after starting.

Open `GNOME Terminal` and type `sudo su -` to login as root.

Type the following commands to set the context properly.

```
export KUBECONFIG=/root/.mykube/config
kubectl config use-context servicemesh
```

Now, you can run `kubectl` commands.

```
kubectl get nodes
```

## Open Web Console

You can open IBM Cloud Private at https://192.168.142.101:8443 from your Apple MacBook. Use user as `admin` and password as `admin` to login.

