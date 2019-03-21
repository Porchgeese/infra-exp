resource "aws_eks_cluster" "porch" {
  name     = "${var.cluster-name}"
  role_arn = "${aws_iam_role.kube-cluster.arn}"

  vpc_config {
    security_group_ids = [
      "${aws_security_group.porch-cluster.id}",
    ]

    subnet_ids = [
      "${aws_subnet.porch.*.id}",
    ]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.porch-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.porch-AmazonEKSServicePolicy",
  ]
}

locals {
  demo-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.porch.endpoint}' --b64-cluster-ca '${aws_eks_cluster.porch.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.kube-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}

output "config_map_aws_auth" {
  value = "${local.config_map_aws_auth}"
}
