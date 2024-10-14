# Requisitos previos
- Crear el par de llaves que se utilizaran para conectarse al bastion
- Desacargarse la llave .pem y pegarla en el raiz del directorio donde se descargo el repo
- Renombrar el archivo terraform.tfvars.sample por terrform.tfvars 
- Cabmiar los valores de las variables
- Tener terraform instalado en la PC de salto

## Para instalar el bastion
Desde una maquina de salto

```
terraform -chdir=bastion/ init 
terraform -chdir=bastion/ plan -out bastion.plan
terraform -chdir=bastion/ apply bastion.plan
```
## Para Desplegar el EKS y el monitoreo
´´´
cd /tmp
./installApps.sh
´´´
## Para destruir el eks
Desde el Bastion
```
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION
``` 
## Para destruir el bastion
desde la PC de salto
```
terraform -chdir=bastion/ plan -out bastion.plan -destroy
terraform -chdir=bastion/ apply bastion.plan
```