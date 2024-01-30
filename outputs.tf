output "eks_cluster_id" {
  value = aws_eks_cluster.tlc.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.tlc.name
}

output "eks_cluster_certificate_data" {
  value = aws_eks_cluster.tlc.certificate_authority.0.data
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.tlc.endpoint
}

output "eks_cluster_nodegroup_id" {
  value = aws_eks_node_group.tlc-node-group.id
}