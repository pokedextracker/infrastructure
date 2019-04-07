#!/bin/bash

# install kubeadm and related tools
apt-get update && apt-get install -y apt-transport-https curl
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
  name: $(curl http://169.254.169.254/latest/meta-data/local-hostname)
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

# copy admin.conf for ubuntu
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# save the token and CA key hash to SSM
KUBEADM_CA_KEY_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
aws ssm put-parameter --name /kubernetes/${name}/kubeadm_token --description 'Kubeadm token to join the cluster' --value $KUBEADM_TOKEN --type SecureString --key-id alias/${name}-kubernetes --region ${region}
aws ssm put-parameter --name /kubernetes/${name}/kubeadm_ca_key_hash --description 'Kubeadm CA key hash to join the cluster' --value $KUBEADM_CA_KEY_HASH --type SecureString --key-id alias/${name}-kubernetes --region ${region}
