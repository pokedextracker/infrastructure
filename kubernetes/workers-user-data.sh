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

# wait for the master to complete bootstrapping
while [ "$(aws ssm get-parameters --name /kubernetes/pokedextracker/kubeadm_ca_key_hash --query 'Parameters[0].Value' --region us-west-2 --output text)" == "None" ]; do
  echo [$(date -u +"%FT%TZ")] - Waiting for master to be ready
  sleep 5
done
echo "Found CA key hash; master is ready"

# fetch secrets from SSM
KUBEADM_TOKEN=$(aws ssm get-parameters --name /kubernetes/${name}/kubeadm_token --with-decryption --query 'Parameters[0].Value' --region ${region} --output text)
KUBEADM_CA_KEY_HASH=$(aws ssm get-parameters --name /kubernetes/${name}/kubeadm_ca_key_hash --with-decryption --query 'Parameters[0].Value' --region ${region} --output text)

# create kubeadm config file
cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta1
discovery:
  bootstrapToken:
    apiServerEndpoint: ${cluster_endpoint_internal}:6443
    token: $KUBEADM_TOKEN
    caCertHashes:
    - "sha256:$KUBEADM_CA_KEY_HASH"
  tlsBootstrapToken: $KUBEADM_TOKEN
kind: JoinConfiguration
nodeRegistration:
  name: $(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
  kubeletExtraArgs:
    cloud-provider: aws
EOF

# run kubeadm
kubeadm join --config /tmp/kubeadm-config.yaml
