#!/bin/bash

# Variables de configuración
#kubctl
export AWS_REGION="us-east-1"
export CLUSTER_NAME="eks-mundos-240100"
export KEY_PAIR="devops"
## Grafana y Prometheus
export NAMESPACE_MONITORING="monitoring"
export PROMETHEUS_RELEASE_NAME="prometheus"
export GRAFANA_RELEASE_NAME="grafana"
export GRAFANA_PORT=8090


aws sts get-caller-identity >> /dev/null
if [ $? -eq 0 ]
then
  echo "Credenciales testeadas, proceder con la creacion de cluster."

  eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --nodes 3 \
    --node-type t2.small \
    --with-oidc \
    --ssh-access \
    --ssh-public-key $KEY_PAIR \
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


aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

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
# echo "Esperando a que se despliegue Grafana..."
# kubectl get pods --namespace $NAMESPACE_MONITORING -l "app.kubernetes.io/name=grafana" --watch

# Obtener la IP del servicio LoadBalancer de Grafana
echo "Obteniendo la IP del servicio de Grafana..."
GRAFANA_IP=$(kubectl get svc --namespace $NAMESPACE_MONITORING $GRAFANA_RELEASE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Grafana se ha desplegado con éxito."
echo "Puedes acceder a Grafana en: http://$GRAFANA_IP:$GRAFANA_PORT"
echo "Usuario: admin"
echo "Contraseña: admin (cámbiala después de iniciar sesión)"

# Finalizar script
echo "Prometheus y Grafana se han desplegado correctamente."