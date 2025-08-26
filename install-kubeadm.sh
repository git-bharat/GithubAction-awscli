The entire **kubeadm installation process** into a **bash script**.
This script will:

* Ask for **node role (master/worker)**.
* Ask for **hostname**, **pod network CIDR**, and **master IP** (for join).
* Automate all the installation & configuration.
* At the end, print the **kubeadm join command** on the master node.

---

# 📜 `install_k8s.sh`

```bash
#!/bin/bash
set -e

# =============================
# Kubernetes Installation Script (Ubuntu)
# =============================

echo "======================================"
echo " 🚀 Kubernetes kubeadm Installation"
echo "======================================"
echo

# Ask for node role
read -p "Enter node role (master/worker): " NODE_ROLE

# Ask for hostname
read -p "Enter hostname for this node: " NODE_HOSTNAME
sudo hostnamectl set-hostname $NODE_HOSTNAME

echo "👉 Updating system..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "👉 Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/' /etc/fstab

echo "👉 Loading kernel modules..."
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# =============================
# Install containerd
# =============================
echo "👉 Installing containerd..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y containerd.io

echo "👉 Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# =============================
# Install kubeadm, kubelet, kubectl
# =============================
echo "👉 Installing Kubernetes components..."
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
    https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# =============================
# Master node setup
# =============================
if [[ "$NODE_ROLE" == "master" ]]; then
    read -p "Enter Pod Network CIDR (default: 192.168.0.0/16): " POD_CIDR
    POD_CIDR=${POD_CIDR:-192.168.0.0/16}

    echo "👉 Initializing control plane..."
    sudo kubeadm init --pod-network-cidr=$POD_CIDR | tee kubeadm-init.out

    echo "👉 Configuring kubectl..."
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo "👉 Installing Calico network plugin..."
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

    echo "======================================"
    echo " ✅ Control plane is ready!"
    echo "👉 Use this command to join worker nodes:"
    grep "kubeadm join" kubeadm-init.out
    echo "======================================"

# =============================
# Worker node setup
# =============================
elif [[ "$NODE_ROLE" == "worker" ]]; then
    read -p "Enter kubeadm join command (from master): " JOIN_CMD
    echo "👉 Joining cluster..."
    sudo $JOIN_CMD
    echo "✅ Worker node joined successfully!"

else
    echo "❌ Invalid role. Please choose 'master' or 'worker'."
    exit 1
fi
```

---

# 🔧 How to Use

1. Save script:

   ```bash
   nano install_k8s.sh
   ```

   (paste the code above)

2. Make executable:

   ```bash
   chmod +x install_k8s.sh
   ```

3. Run on each node:

   ```bash
   ./install_k8s.sh
   ```

4. Choose `master` on the control plane node (enter Pod CIDR if needed).
   It will give you a **kubeadm join** command.

5. Run the script on each worker node, select `worker`, and paste the join command.


