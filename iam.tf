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
  policy = file("${path.root}/policies/csi_iam_policy.json")
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


resource "aws_iam_policy" "ALBIngressControllerIAMPolicy" {
  name        = "ALBIngressControllerIAMPolicy"
  description = "IAM policy for the AWS Load Balancer Controller"
  policy      = file("${path.root}/policies/lb_iam_policy.json")
}
resource "aws_iam_role" "ALBIngressControllerRole" {
  name = "alb-ingress-controller"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:kube-system:alb-ingress-controller",
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY


  tags = {
    "ServiceAccountName"      = "alb-ingress-controller"
    "ServiceAccountNameSpace" = "kube-system"
  }
}

# Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-ALBIngressControllerIAMPolicy" {
  policy_arn = aws_iam_policy.ALBIngressControllerIAMPolicy.arn
  role       = aws_iam_role.ALBIngressControllerRole.name
  depends_on = [aws_iam_role.ALBIngressControllerRole]
}

resource "aws_iam_role_policy_attachment" "alb-ingress-controller-role-AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.ALBIngressControllerRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  depends_on = [aws_iam_role.ALBIngressControllerRole]
}

