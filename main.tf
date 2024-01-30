provider "aws" {
  region = var.aws_region
}

# cluster access management

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

resource "aws_iam_role" "tlc-cluster" {
  name = local.cluster_name

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "tlc-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.tlc-cluster.name
}

# network security policy

resource "aws_security_group" "tlc-cluster" {
  name   = local.cluster_name
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tlc"
  }
}

# cluster definition

resource "aws_eks_cluster" "tlc" {
  name     = local.cluster_name
  role_arn = aws_iam_role.tlc-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.tlc-cluster.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.tlc-cluster-AmazonEKSClusterPolicy
  ]
}

# node group IAM
## node role
resource "aws_iam_role" "tlc-node" {
  name = "${local.cluster_name}.node"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

## node policy
resource "aws_iam_role_policy_attachment" "tlc-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.tlc-node.name
}

resource "aws_iam_role_policy_attachment" "tlc-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.tlc-node.name
}

resource "aws_iam_role_policy_attachment" "tlc-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.tlc-node.name
}

# node group

resource "aws_eks_node_group" "tlc-node-group" {
  cluster_name    = aws_eks_cluster.tlc.name
  node_group_name = "tlc"
  node_role_arn   = aws_iam_role.tlc-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.tlc-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.tlc-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.tlc-node-AmazonEC2ContainerRegistryReadOnly
  ]
}

# create a kubeconfig file based on the cluster that has been created
resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG_END
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.tlc.certificate_authority.0.data}
    server: ${aws_eks_cluster.tlc.endpoint}
    name: ${aws_eks_cluster.tlc.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.tlc.arn}
    user: ${aws_eks_cluster.tlc.arn}
    name: ${aws_eks_cluster.tlc.arn}
current_context: ${aws_eks_cluster.tlc.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.tlc.arn}
    user:
    exec:
        apiVersion: cluent.authentication.k8s.io/v1alpha1
        command: aws-iam-authenticator
        args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.tlc.name}"
KUBECONFIG_END
  filename = "kubeconfig"
}