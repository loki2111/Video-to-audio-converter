terraform {
  required_version = ">= 1.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  #access_key = "xxxxxxxxxxxxxxxxxxxxxx"
  #secret_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

# Security Group
resource "aws_security_group" "eks_security_group" {
  name        = "eks-security-group"
  description = "Security group for EKS"
  vpc_id      = "vpc-042d606255c381138"
 // Inbound rule 1:
  ingress {
    from_port   = 30005
    to_port     = 30005
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "mongodb"
  }
  ingress {
    from_port   = 30004
    to_port     = 30004
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "rabbit"
  }

  ingress {
    from_port   = 30003
    to_port     = 30003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "postgres"
  }

  ingress {
    from_port   = 30002
    to_port     = 30002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "gateway"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ssh"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "k8s-nodes"
  }
  // Outbound rule: Allow all traffic to go out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# IAM Role and EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "eks_cluster_policy_attachment" {
  name       = "eks-cluster-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  roles      = [aws_iam_role.eks_cluster_role.name]
}
resource "aws_iam_policy_attachment" "eks_cni_policy_attachment" {
  name       = "eks_cni_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  roles      = [aws_iam_role.eks_cluster_role.name]
}


resource "aws_eks_cluster" "eks_cluster" {
  name     = "video-to-audio"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = ["subnet-07552c0c81f4bc194", "subnet-0317f4ef9bb005f22", "subnet-076f5d55e8d21708d", "subnet-0bf575fe7cbf6fea1"] # Specify your subnet ids
    security_group_ids = [aws_security_group.eks_security_group.id]  # Use the created security group for the EKS cluster


    endpoint_private_access = true
    endpoint_public_access  = true
  }
  depends_on = [aws_security_group.eks_security_group]  # Express dependency on the security group

}

# IAM Role and Worker NodeGroup
resource "aws_iam_role" "eks_worker_role" {
  name = "eks-worker-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "eks_worker_policy_attachment" {
  name       = "eks-worker-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  roles      = [aws_iam_role.eks_worker_role.name]
}

resource "aws_iam_policy_attachment" "eks_worker_node_policy_attachment" {
  name       = "eks-worker-node-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  roles      = [aws_iam_role.eks_worker_role.name]
}

resource "aws_iam_policy_attachment" "ecr_readonly_policy_attachment" {
  name       = "ecr-readonly-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  roles      = [aws_iam_role.eks_worker_role.name]
}

resource "aws_iam_policy_attachment" "amazonebscsidriverpolicy-attachment" {
  name       = "amazonebscsidriverpolicy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  roles      = [aws_iam_role.eks_worker_role.name]
}



# EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "video-to-audio-workernode"
  subnet_ids      = ["subnet-07552c0c81f4bc194", "subnet-0317f4ef9bb005f22", "subnet-076f5d55e8d21708d", "subnet-0bf575fe7cbf6fea1"] #specify subnets

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }



  remote_access {
    ec2_ssh_key = "PROJECT"
  }

  instance_types = ["t3.medium"] # Specify your desired instance type, min t2.medium required 

  # IAM role ARN for the worker nodes
  node_role_arn = aws_iam_role.eks_worker_role.arn

  depends_on = [aws_eks_cluster.eks_cluster]
}

