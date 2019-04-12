#!/bin/bash

# install NFS tools and mount EFS
apt-get update
apt-get -y install nfs-common
mkdir -p /mnt
mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /mnt

# install kubeadm and related tools
apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
KUBE_VERSION=$(apt-cache madison kubeadm | grep '\b${kubernetes_version}-\b' | tr -s ' ' | cut -f2 -d'|' | sed 's/ //' | head -n1)
apt-get install -y kubelet=$KUBE_VERSION kubeadm=$KUBE_VERSION kubectl=$KUBE_VERSION
apt-mark hold kubelet kubeadm kubectl

# install and setup docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce=18.06.2~ce~3-0~ubuntu
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

# set the hostnames correctly
echo 127.0.0.1 $(curl -s http://169.254.169.254/latest/meta-data/hostname) >> /etc/hosts
curl -s http://169.254.169.254/latest/meta-data/hostname > /etc/hostname
hostname $(curl -s http://169.254.169.254/latest/meta-data/hostname)

# generate our own kubelet certs instead of letting kubelet bootstrap them
# itself because if it did that, it would generate a CA on the fly and not
# write it out to a file, making it impossible to verify the certificate when
# making requests against it
pushd /tmp
openssl genrsa -out kubelet-ca.key 2048
openssl req -x509 -new -nodes -key kubelet-ca.key -subj "/CN=$(curl -s http://169.254.169.254/latest/meta-data/hostname)-ca" -days 10000 -out kubelet-ca.crt
openssl genrsa -out kubelet.key 2048
cat > csr.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = $(curl -s http://169.254.169.254/latest/meta-data/hostname)

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $(curl -s http://169.254.169.254/latest/meta-data/hostname)

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF
openssl req -new -key kubelet.key -out kubelet.csr -config csr.conf
openssl x509 -req -in kubelet.csr -CA kubelet-ca.crt -CAkey kubelet-ca.key -CAcreateserial -out kubelet.crt -days 10000 -extensions v3_ext -extfile csr.conf
rm -rf /var/lib/kubelet/pki/*
mv kubelet-ca.crt kubelet-ca.key kubelet.crt kubelet.key /var/lib/kubelet/pki/
service kubelet restart
popd

# set necessary system configs
modprobe br_netfilter
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# install the aws cli
apt-get install -y python3-distutils unzip
pushd /tmp
curl -s https://s3.amazonaws.com/aws-cli/awscli-bundle.zip -o awscli-bundle.zip
unzip awscli-bundle.zip
python3 awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
popd

# acquire lock within EFS to ensure one master bootstraps the cluster
exec 200> /mnt/lock
flock -x 200

if [ ! -f /mnt/kubernetes/pki/ca.key ]; then
  # create Route53 records with the public and private IPs
  aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --change-batch '
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Type": "A",
      "TTL": 60,
      "Name": "${cluster_endpoint_internal}",
      "MultiValueAnswer": true,
      "SetIdentifier": "'"$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"'",
      "ResourceRecords": [{
        "Value": "'"$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"'"
      }]
    }
  }]
}'
  aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --change-batch '
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Type": "A",
      "TTL": 60,
      "Name": "${cluster_endpoint}",
      "MultiValueAnswer": true,
      "SetIdentifier": "'"$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"'",
      "ResourceRecords": [{
        "Value": "'"$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"'"
      }]
    }
  }]
}'

  # wait 10 seconds and flush the DNS cache
  sleep 10
  systemd-resolve --flush-caches

  # create encryption config
  mkdir -p /etc/kubernetes
  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
  cat > /etc/kubernetes/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: $ENCRYPTION_KEY
    - identity: {}
EOF

  # generate the token that other nodes will use to join the cluster
  KUBEADM_TOKEN=$(kubeadm token generate)

  # create kubeadm config file
  cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta1
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: $KUBEADM_TOKEN
  ttl: 0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
nodeRegistration:
  name: $(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
  kubeletExtraArgs:
    cloud-provider: aws
---
apiVersion: kubeadm.k8s.io/v1beta1
clusterName: "${name}"
controlPlaneEndpoint: ${cluster_endpoint_internal}:6443
kind: ClusterConfiguration
kubernetesVersion: v${kubernetes_version}
networking:
  podSubnet: ${pod_subnet}
  serviceSubnet: ${service_subnet}
apiServer:
  certSANs:
  - ${cluster_endpoint}
  extraArgs:
    cloud-provider: aws
    encryption-provider-config: /etc/kubernetes/encryption-config.yaml
  extraVolumes:
  - name: encryption-config
    hostPath: /etc/kubernetes/encryption-config.yaml
    mountPath: /etc/kubernetes/encryption-config.yaml
    readOnly: true
controllerManager:
  extraArgs:
    cloud-provider: aws
EOF

  # run kubeadm
  kubeadm init --config /tmp/kubeadm-config.yaml

  # install flannel
  cat <<EOF | kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
rules:
  - apiGroups: ['extensions']
    resources: ['podsecuritypolicies']
    verbs: ['use']
    resourceNames: ['psp.flannel.unprivileged']
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "${pod_subnet}",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: kube-flannel-ds-amd64
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      hostNetwork: true
      nodeSelector:
        beta.kubernetes.io/arch: amd64
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.11.0-amd64
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-amd64
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
             add: ["NET_ADMIN"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
EOF

  # install EBS gp2 storage class
  kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/storage-class/aws/default.yaml

  # save the token and CA key hash to SSM
  KUBEADM_CA_KEY_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
  aws ssm put-parameter --name /kubernetes/${name}/encryption_key --description 'Encryption key for Kubernetes secrets' --value $ENCRYPTION_KEY --type SecureString --key-id alias/${name}-kubernetes --region ${region}
  aws ssm put-parameter --name /kubernetes/${name}/kubeadm_token --description 'Kubeadm token to join the cluster' --value $KUBEADM_TOKEN --type SecureString --key-id alias/${name}-kubernetes --region ${region}
  aws ssm put-parameter --name /kubernetes/${name}/kubeadm_ca_key_hash --description 'Kubeadm CA key hash to join the cluster' --value $KUBEADM_CA_KEY_HASH --type SecureString --key-id alias/${name}-kubernetes --region ${region}

  # copy necessary certificates to EFS
  mkdir -p /mnt/kubernetes/pki/etcd/
  cp /etc/kubernetes/pki/ca.crt /mnt/kubernetes/pki/ca.crt
  cp /etc/kubernetes/pki/ca.key /mnt/kubernetes/pki/ca.key
  cp /etc/kubernetes/pki/sa.key /mnt/kubernetes/pki/sa.key
  cp /etc/kubernetes/pki/sa.pub /mnt/kubernetes/pki/sa.pub
  cp /etc/kubernetes/pki/front-proxy-ca.crt /mnt/kubernetes/pki/front-proxy-ca.crt
  cp /etc/kubernetes/pki/front-proxy-ca.key /mnt/kubernetes/pki/front-proxy-ca.key
  cp /etc/kubernetes/pki/etcd/ca.crt /mnt/kubernetes/pki/etcd/ca.crt
  cp /etc/kubernetes/pki/etcd/ca.key /mnt/kubernetes/pki/etcd/ca.key
  cp /etc/kubernetes/admin.conf /mnt/kubernetes/admin.conf

  # release lock since we're done bootstrapping
  flock -u 200
else
  # release lock since we don't need it anymore
  flock -u 200

  # copy necessary certificates from EFS to their appropriate locations
  mkdir -p /etc/kubernetes/pki/etcd/
  cp /mnt/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.crt
  cp /mnt/kubernetes/pki/ca.key /etc/kubernetes/pki/ca.key
  cp /mnt/kubernetes/pki/sa.key /etc/kubernetes/pki/sa.key
  cp /mnt/kubernetes/pki/sa.pub /etc/kubernetes/pki/sa.pub
  cp /mnt/kubernetes/pki/front-proxy-ca.crt /etc/kubernetes/pki/front-proxy-ca.crt
  cp /mnt/kubernetes/pki/front-proxy-ca.key /etc/kubernetes/pki/front-proxy-ca.key
  cp /mnt/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/ca.crt
  cp /mnt/kubernetes/pki/etcd/ca.key /etc/kubernetes/pki/etcd/ca.key
  cp /mnt/kubernetes/admin.conf /etc/kubernetes/admin.conf

  # fetch secrets
  ENCRYPTION_KEY=$(aws ssm get-parameters --name /kubernetes/${name}/encryption_key --with-decryption --query 'Parameters[0].Value' --region ${region} --output text)
  KUBEADM_TOKEN=$(aws ssm get-parameters --name /kubernetes/${name}/kubeadm_token --with-decryption --query 'Parameters[0].Value' --region ${region} --output text)
  KUBEADM_CA_KEY_HASH=$(aws ssm get-parameters --name /kubernetes/${name}/kubeadm_ca_key_hash --with-decryption --query 'Parameters[0].Value' --region ${region} --output text)

  # create encryption config
  cat > /etc/kubernetes/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: $ENCRYPTION_KEY
    - identity: {}
EOF

  # join the cluster
  kubeadm join ${cluster_endpoint_internal}:6443 --token $KUBEADM_TOKEN --discovery-token-ca-cert-hash $KUBEADM_CA_KEY_HASH --experimental-control-plane

  # create Route53 records with the public and private IPs
  aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --change-batch '
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Type": "A",
      "TTL": 60,
      "Name": "${cluster_endpoint_internal}",
      "MultiValueAnswer": true,
      "SetIdentifier": "'"$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"'",
      "ResourceRecords": [{
        "Value": "'"$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"'"
      }]
    }
  }]
}'
  aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --change-batch '
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Type": "A",
      "TTL": 60,
      "Name": "${cluster_endpoint}",
      "MultiValueAnswer": true,
      "SetIdentifier": "'"$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"'",
      "ResourceRecords": [{
        "Value": "'"$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"'"
      }]
    }
  }]
}'

  # wait 10 seconds and flush the DNS cache
  sleep 10
  systemd-resolve --flush-caches
fi

# copy admin.conf for ubuntu
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
