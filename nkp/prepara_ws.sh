#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 1. Instalar docker y configurar a nutanix y mi usuario para usarlo

sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io
sudo systemctl --now enable docker
sudo usermod -aG docker nutanix
sudo usermod -aG docker victor.dgibbs

# 2. Instalar kubectl, bash y kubecolor

sudo curl -Lo /usr/local/bin/kubectl https://dl.k8s.io/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | sudo bash
curl -LO https://github.com/kubecolor/kubecolor/releases/download/v0.6.0/kubecolor_0.6.0_linux_amd64.tar.gz
tar zxvf kubecolor_0.6.0_linux_amd64.tar.gz
sudo mv kubecolor /usr/local/bin

# 3. setear .bashrc con bash-completion

alias k=kubecolor
sudo dnf install bash-completion -y
echo "source /etc/bash_completion.d/authselect-completion.sh" >> .bashrc
echo 'alias k="kubecolor"' >>~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'source <(helm completion bash)' >>~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

# 4. Borrar archivos innecesarios:

rm LICENSE
rm kubecolor_0.6.0_linux_amd64.tar.gz

# 5. Fin
echo -e "${GREEN}Listo.${NC}"
