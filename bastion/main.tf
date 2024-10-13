terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

# VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "eks_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_route_table" "eks_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-route-table"
  }
}

resource "aws_route_table_association" "eks_route_table_assoc" {
  count          = 3
  subnet_id      = aws_subnet.eks_subnet[count.index].id
  route_table_id = aws_route_table.eks_route_table.id
}






# EC2 Instance
resource "aws_instance" "ec2_instance" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  key_name               = var.ec2_key_name
  subnet_id              = aws_subnet.eks_subnet[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.id  

  tags = {
    Name = var.ec2_name
  }

  # Provisión del archivo remoto y ejecución
  provisioner "file" {
    source      = "./scripts/install.sh"
    destination = "/tmp/install.sh"

    connection {
      type        = "ssh"
      user        = var.ec2_user
      private_key = file(var.ssh_private_key) 
      host        = self.public_ip
    }
  }

    provisioner "file" {
    source      = "./scripts/install-apps.sh"
    destination = "/tmp/installApps.sh"

    connection {
      type        = "ssh"
      user        = var.ec2_user
      private_key = file(var.ssh_private_key) 
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo echo AWS_REGION=${var.region} >> /home/${var.ec2_user}/.profile",
      "sudo echo CLUSTER_NAME=${var.cluster_name} >> /home/${var.ec2_user}/.profile",
      "sudo echo KEY_PAIR=${var.ec2_key_name} >> /home/${var.ec2_user}/.profile",
      "chmod +x /tmp/*.sh",
      "sudo apt update -y",
      "sudo apt install dos2unix -y",
      "dos2unix /tmp/install.sh",      
      "sudo /tmp/install.sh"
    ]

    connection {
      type        = "ssh"
      user        = var.ec2_user
      private_key = file(var.ssh_private_key)
      host        = self.public_ip
    }
  }
}

# Políticas IAM necesarias para acceso completo
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AdministratorAccess",  # Acceso administrativo completo a todos los servicios
    "arn:aws:iam::aws:policy/IAMFullAccess",  # Permite gestionar IAM
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",  # Permisos completos de EKS
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",  # Acceso completo a EC2
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",  # CloudWatch logs access
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",  # Permite acceso total a SSM
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess",  # Permite gestionar CloudFormation
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",  # Acceso completo a S3
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",  # Acceso completo a RDS
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess"  # Permite gestionar redes y subnets
  ])
  policy_arn = each.value
  role       = aws_iam_role.ec2_iam_role.name
}

# Crear un nuevo IAM Role para la instancia EC2
resource "aws_iam_role" "ec2_iam_role" {
  name = "${var.cluster_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Crear el perfil de instancia para la EC2 usando el nuevo rol
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.cluster_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_iam_role.name
}


# Security Group para EC2
resource "aws_security_group" "ec2_sg" {
  name        = "${var.cluster_name}-ec2-security-group"
  description = "Security group for EC2 instance and EKS"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}