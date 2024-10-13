variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
}

variable "region" {
  description = "La región de AWS donde se desplegará el clúster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "El nombre del clúster EKS"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = ""
}

variable "node_group_desired_size" {
  description = "Tamaño deseado del grupo de nodos"
  type        = number
}

variable "node_group_max_size" {
  description = "Tamaño máximo del grupo de nodos"
type        = number
}

variable "node_group_min_size" {
  description = "Tamaño mínimo del grupo de nodos"
  type        = number
}

variable "node_group_instance_type" {
  description = "Tipo de instancia del grupo de nodos"
  type        = string
}

variable "ec2_ami" {
  description = "AMI para la instancia EC2"
  type        = string
  default     = "ami-005fc0f236362e99f"  
}

variable "ec2_instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "ec2_key_name" {
  description = "Name of the key pair to connect to EC2"
  type        = string
}

variable "ec2_name" {
  description = "Nombre de la instancia EC2"
  type        = string
  default     = ""
}

variable "ssh_private_key" {
  description = "Ruta a la clave privada SSH para la conexión a la instancia EC2"
  type        = string
  default = "./devops.pem"
}

variable "ec2_user" {
  description = "Ruta a la clave privada SSH para la conexión a la instancia EC2"
  type        = string
  default = "ubuntu"
}