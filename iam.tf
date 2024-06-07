resource "aws_iam_role" "fargate_role" {
  name = "fargate_role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_role.name
}

resource "aws_iam_policy" "csi_iam_policy" {
  policy = file("./policies/csi_iam_policy.json")
}

resource "aws_iam_role" "AmazonEKS_EFS_CSI_DriverRole" {
  name = "AmazonEKS_EFS_CSI_DriverRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "${module.eks.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "csi_iam_policy_attatch" {
  policy_arn = aws_iam_policy.csi_iam_policy.arn
  role       = aws_iam_role.AmazonEKS_EFS_CSI_DriverRole.name
}

resource "aws_iam_policy" "AWSLoadBalancerControllerIAMPolicy" {
  policy = file("./policies/lb_iam_policy.json")
}

