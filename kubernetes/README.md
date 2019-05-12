# Kubernetes

This Terraform service creates all of the necessary resources for a Kubernetes
cluster.

## Rolling Masters

When changes are made to the user data script of the masters, the following
steps need to be taken to safely cycle the master nodes in the cluster to get
the new changes.

1. Apply the Terraform changes.
    ```sh
    terraform apply
    ```
2. Increase the size of the master autoscaling group temporarily to get a new
   master to be created and join the cluster.
    ```sh
    aws autoscaling set-desired-capacity \
      --auto-scaling-group-name pokedextracker-kubernetes-masters \
      --desired-capacity 2 \
      --honor-cooldown
    ```
3. Wait for the new master to join the cluster.
    ```sh
    watch kubectl get nodes
    ```
    >Note: If there is a problem with your new user data, it's very likely that
    >the new master won't successfully bootstrap, and it will never join the
    >cluster. If you wait for 5-10 minutes and the new node doesn't join, you
    >should SSH into the new node and investigate
    >`/var/log/cloud-init-output.log` to identify any issues.
4. Once the new master has joined, remove the old master's IPs from the internal
   and external DNS records. This can be done through the Route 53 console.
    >Note: Make sure you remove the _old_ node and not the new one.
5. After waiting the DNS TTL, confirm that the old node's IP is no longer being
   returned for `k8s.pokedextracker.com`.
    ```sh
    dig k8s.pokedextracker.com
    ```
6. Once the IPs are no longer being returned, drain the old master.
    ```sh
    kubectl drain <node_name> --ignore-daemonsets --force
    ```
7. Remove the old etcd member from the etcd cluster. This requires SSHing into
   one of the masters and running an etcd container (since you can't install
   `etcdctl` without installing all of etcd, and our etcd nodes run in
   containers).
    ```sh
    docker run \
      --rm \
      -it \
      --net host \
      -v /etc/kubernetes:/etc/kubernetes \
      quay.io/coreos/etcd \
      /bin/sh
    ```
    ```sh
    # store all the endpoints into a variable
    ENDPOINTS=$(ETCDCTL_API=3 etcdctl \
      --cert=/etc/kubernetes/pki/etcd/peer.crt \
      --key=/etc/kubernetes/pki/etcd/peer.key \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --endpoints="https://localhost:2379" \
      member list \
      | awk -vORS=, '{ print $5 }' \
      | sed 's/,$//')

    # list all the members to find the ID of the old member
    ETCDCTL_API=3 etcdctl \
      --cert=/etc/kubernetes/pki/etcd/peer.crt \
      --key=/etc/kubernetes/pki/etcd/peer.key \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --endpoints="https://localhost:2379" \
      member list

    # remove the old node
    ETCDCTL_API=3 etcdctl \
      --cert=/etc/kubernetes/pki/etcd/peer.crt \
      --key=/etc/kubernetes/pki/etcd/peer.key \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --endpoints=$ENDPOINTS \
      member remove <old_node_id>
    ```
8. Decrement the size of the master autoscaling group to get AWS to terminate
   our old node. Because of our termination policies, we can say with confidence
   that it will be the oldest node that will be terminated.
   ```sh
    aws autoscaling set-desired-capacity \
      --auto-scaling-group-name pokedextracker-kubernetes-masters \
      --desired-capacity 1 \
      --honor-cooldown
   ```
   >Note: If for some reason, we don't want to terminate the oldest node, we
   >will have to detach the desired node from the autoscaling group with the
   >flag `--should-decrement-desired-capacity`. Then, once it's detached, we can
   >terminate it safely.

## Rolling Workers

When changes are made to the user data script of the workers, the following
steps need to be taken to safely cycle the worker nodes in the cluster to get
the new changes. **While these are similar to the steps to roll masters, it's a
bit simpler.**

1. Apply the Terraform changes.
    ```sh
    terraform apply
    ```
2. Increase the size of the worker autoscaling group temporarily to get a new
   worker to be created and join the cluster.
    ```sh
    aws autoscaling set-desired-capacity \
      --auto-scaling-group-name pokedextracker-kubernetes-workers \
      --desired-capacity 2 \
      --honor-cooldown
    ```
3. Wait for the new worker to join the cluster.
    ```sh
    watch kubectl get nodes
    ```
    >Note: If there is a problem with your new user data, it's very likely that
    >the new worker won't successfully bootstrap, and it will never join the
    >cluster. If you wait for 5-10 minutes and the new node doesn't join, you
    >should SSH into the new node and investigate
    >`/var/log/cloud-init-output.log` to identify any issues.
4. Once the new worker has joined, drain the old worker.
    ```sh
    kubectl drain <node_name> --ignore-daemonsets --force
    ```
5. Decrement the size of the worker autoscaling group to get AWS to terminate
   our old node. Because of our termination policies, we can say with confidence
   that it will be the oldest node that will be terminated.
   ```sh
    aws autoscaling set-desired-capacity \
      --auto-scaling-group-name pokedextracker-kubernetes-workers \
      --desired-capacity 1 \
      --honor-cooldown
   ```
   >Note: If for some reason, we don't want to terminate the oldest node, we
   >will have to detach the desired node from the autoscaling group with the
   >flag `--should-decrement-desired-capacity`. Then, once it's detached, we can
   >terminate it safely.
