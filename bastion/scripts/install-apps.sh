#!/bin/bash

## Instalacion del EKS
aws sts get-caller-identity >> /dev/null

eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --nodes 3 \
  --node-type $NODE_SIZE \
  --with-oidc \
  --ssh-access \
  --ssh-public-key $KEY_PAIR \
  --managed \
  --full-ecr-access \
  --zones us-east-1a,us-east-1b,us-east-1c

## Actualizar kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

##Intalacion el EBS CSI Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.30"

eksctl create iamserviceaccount \
 --name ebs-csi-controller-sa \
 --region $AWS_REGION \
 --namespace kube-system \
 --cluster $CLUSTER_NAME \
 --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
 --approve \
 --role-only \
 --role-name AmazonEKS_EBS_CSI_DriverRole

 # Obtener el ID de la cuenta y almacenarlo en una variable
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Ejecutar el comando eksctl con la variable ACCOUNT_ID
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster $CLUSTER_NAME \
  --service-account-role-arn arn:aws:iam::$ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole \
  --force

## Instalacion de NGINX
kubectl apply -f /tmp/nginx.yaml

# Agregar repo de prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Agregar repo de grafana
helm repo add grafana https://grafana.github.io/helm-charts

helm repo update


## Grafana y Prometheus


# Crear el namespace prometheus
kubectl create namespace prometheus

# Desplegar prometheus en EKS

helm install prometheus prometheus-community/prometheus \
--namespace prometheus \
--set alertmanager.persistentVolume.storageClass="gp2" \
--set server.persistentVolume.storageClass="gp2"

# Verificar la instalación
kubectl get all -n prometheus

# Exponer prometheus en la instancia de EC2 en el puerto 8080
kubectl port-forward -n prometheus deploy/prometheus-server 8080:9090 --address 0.0.0.0

kubectl create namespace grafana

helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.storageClassName="gp2" \
    --set persistence.enabled=true \
    --set adminPassword=$GRAFANA_PASS \
    --values /tmp/grafana.yaml \
    --set service.type=LoadBalancer