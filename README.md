## Para instalar el bastion
Desde una maquina de salto

```
terraform -chdir=bastion/ init 
terraform -chdir=bastion/ plan -out bastion.plan
terraform -chdir=bastion/ apply bastion.plan
```

```
terraform -chdir=bastion/ apply bastion.plan
```