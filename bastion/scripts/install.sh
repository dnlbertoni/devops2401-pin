#!/bin/bash

# Variables de configuración
#kubctl
export AWS_REGION="us-east-1"
export CLUSTER_NAME="eks-mundos-240100"
## Grafana y Prometheus
export NAMESPACE_MONITORING="monitoring"
export PROMETHEUS_RELEASE_NAME="prometheus"
export GRAFANA_RELEASE_NAME="grafana"
export GRAFANA_PORT=8090

# Actualizar el caché de paquetes
sudo apt update 
sudo apt upgrade -y
sudo apt install -y unzip ca-certificates curl curl git


# Instalar awscli
curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install

# Kubectl
curl -L "https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.2/2023-03-17/bin/linux/amd64/kubectl" -o "/usr/local/bin/kubectl"
sudo chmod +x /usr/local/bin/kubectl
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc


# eksctl
echo "Installing ekctl"
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
export PATH=$PATH:/usr/local/bin
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
eksctl version

## Desacargas de repos e instalacion
# Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y docker-ce docker-compose helm terraform
sudo systemctl enable docker
sudo systemctl start docker


aws sts get-caller-identity >> /dev/null
if [ $? -eq 0 ]
then
  echo "Credenciales testeadas, proceder con la creacion de cluster."


  eksctl create cluster \
    --name eks-mundos-e2401 \
    --region us-east-1 \
    --nodes 3 \
    --node-type t2.small \
    --with-oidc \
    --ssh-access \
    --ssh-public-key devops \
    --managed \
    --full-ecr-access \
    --zones us-east-1a,us-east-1b,us-east-1c

  if [ $? -eq 0 ]
  then
    echo "Cluster Setup Completo con eksctl ."
  else
    echo "Cluster Setup Falló mientras se ejecuto eksctl."
  fi
else
  echo "Please run aws configure & set right credentials."
  echo "Cluster setup failed."
fi


aws eks update-kubeconfig --name eks-mundos-e2401 --region us-east-1

## Instalacion de aplicaciones

git clone https://github.com/dnlbertoni/devops2401-pin.git /tmp/devops2401-pin

cd /tmp/devops2401-pin/kubernetes/
kubectl apply -f ./00-namespace.yaml
kubectl apply -f ./01-nginx-deploment.yaml
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=rele ase-1.20"


## instalacion de Grafana y Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Crear namespace si no existe
kubectl get namespace $NAMESPACE_MONITORING >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Creando namespace $NAMESPACE_MONITORING..."
  kubectl create namespace $NAMESPACE_MONITORING
else
  echo "El namespace $NAMESPACE_MONITORING ya existe."
fi

# Desplegar Prometheus con ClusterIP (interno)
echo "Desplegando Prometheus..."
helm install $PROMETHEUS_RELEASE_NAME prometheus-community/prometheus \
  --namespace $NAMESPACE_MONITORING \
  --set server.service.type=ClusterIP \
  --set alertmanager.service.type=ClusterIP \
  --set pushgateway.service.type=ClusterIP

# Esperar unos segundos para asegurarse de que los pods de Prometheus se inicien
sleep 10

# Desplegar Grafana con LoadBalancer y expuesto en el puerto 8080
echo "Desplegando Grafana..."
helm install $GRAFANA_RELEASE_NAME grafana/grafana \
  --namespace $NAMESPACE_MONITORING \
  --set adminPassword='admin' \
  --set service.type=LoadBalancer \
  --set service.port=$GRAFANA_PORT \
  --set service.targetPort=3000 \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-backend-protocol"="tcp" \
  --set persistence.enabled=true \
  --set persistence.storageClassName="standard" \
  --set persistence.size=10Gi

# Obtener la contraseña de Grafana
echo "Esperando a que se despliegue Grafana..."
kubectl get pods --namespace $NAMESPACE_MONITORING -l "app.kubernetes.io/name=grafana" --watch

# Obtener la IP del servicio LoadBalancer de Grafana
echo "Obteniendo la IP del servicio de Grafana..."
GRAFANA_IP=$(kubectl get svc --namespace $NAMESPACE_MONITORING $GRAFANA_RELEASE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Grafana se ha desplegado con éxito."
echo "Puedes acceder a Grafana en: http://$GRAFANA_IP:$GRAFANA_PORT"
echo "Usuario: admin"
echo "Contraseña: admin (cámbiala después de iniciar sesión)"

# Finalizar script
echo "Prometheus y Grafana se han desplegado correctamente."