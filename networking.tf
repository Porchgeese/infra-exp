resource "aws_vpc" "porch" {
  cidr_block = "10.0.0.0/16"

  tags = "${
    map(
     "Name", "terraform-eks-porch-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared"
    )
  }"
}

resource "aws_subnet" "porch" {
  count             = 2
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.porch.id}"

  tags = "${
    map(
     "Name", "terraform-eks-demo-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared"
    )
  }"
}

resource "aws_internet_gateway" "porch" {
  vpc_id = "${aws_vpc.porch.id}"

  tags = {
    Name = "terraform-eks-porch"
  }
}

resource "aws_route_table" "porch" {
  vpc_id = "${aws_vpc.porch.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.porch.id}"
  }
}

resource "aws_route_table_association" "demo" {
  count          = 2
  subnet_id      = "${aws_subnet.porch.*.id[count.index]}"
  route_table_id = "${aws_route_table.porch.id}"
}


resource "aws_security_group" "porch-cluster" {
  name        = "terraform-eks-porch-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${aws_vpc.porch.id}"

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = {
    Name = "terraform-eks-demo"
  }
}

resource "aws_security_group" "porch-node" {
  name        = "terraform-eks-demo-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.porch.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "terraform-eks-demo-node",
     "kubernetes.io/cluster/${var.cluster-name}", "owned"
    )
  }"
}

resource "aws_security_group_rule" "porch-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.porch-node.id}"
  source_security_group_id = "${aws_security_group.porch-node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "porch-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.porch-node.id}"
  source_security_group_id = "${aws_security_group.porch-cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "porch-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.porch-cluster.id}"
  source_security_group_id = "${aws_security_group.porch-node.id}"
  to_port                  = 443
  type                     = "ingress"
}