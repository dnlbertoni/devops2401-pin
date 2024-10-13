## Para instalar el bastion
Desde una maquina de salto

```
terraform -chdir=bastion/ init 
terraform -chdir=bastion/ plan -out bastion.plan
terraform -chdir=bastion/ apply bastion.plan
```
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