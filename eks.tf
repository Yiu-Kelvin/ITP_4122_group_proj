data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# data "http" "efs_csi" {
#   url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/deploy/kubernetes/base/csidriver.yaml"
#   request_headers = {
#     Accept = "text/plain"
#   }
# }

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  config_context_cluster = module.eks.cluster_name
  load_config_file       = false
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

module "eks" {
  source                         = "terraform-aws-modules/eks/aws"
  cluster_name                   = "eks-fargate-cluster"
  cluster_version                = "1.30"
  subnet_ids                     = module.vpc.private_subnets
  vpc_id                         = module.vpc.vpc_id
  cluster_endpoint_public_access = true
  cluster_addons = {
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
        resources = {
          limits = {
            cpu    = "0.25"
            memory = "256M"
          }
          requests = {
            cpu    = "0.25"
            memory = "256M"
          }
        }
      })
    }
    kube-proxy = {}
    vpc-cni    = {}
  }
  fargate_profiles = {
    cluster = {
      cluster_name = "eks-fargate-cluster"
      subnet_ids   = module.vpc.private_subnets
      selectors = [
        {
          namespace = "default"
        }
      ]
    }
    kube_system = {
      name = "kube-system"
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }
}
resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = data.aws_caller_identity.current.arn

  access_scope {
    type = "cluster"
  }
}
resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_caller_identity.current.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "access_entry" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = data.aws_caller_identity.current.arn
  kubernetes_groups = ["storage.k8s.io"]
  type              = "STANDARD"
}

# resource "kubectl_manifest" "efs_csi" {
#   yaml_body = data.http.efs_csi.body
# }

resource "kubectl_manifest" "efs_pv" {
  yaml_body  = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: ${aws_efs_file_system.moodle-volume.id}
YAML
}

resource "kubectl_manifest" "efs_storage_class" {
  yaml_body = <<YAML
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  fileSystemId: ${aws_efs_file_system.moodle-volume.id}
  provisioningMode: efs-ap
YAML
}

resource "kubectl_manifest" "efs_pvc" {
  yaml_body  = <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
YAML
  depends_on = [kubectl_manifest.efs_storage_class, kubectl_manifest.efs_pv]
}
resource "helm_release" "latest" {
  name       = "latests"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "moodle"
  values = [templatefile("values.yaml", {
    app_username = "admin"
    app_password = "aA!12345678"
    db_endpoint  = "${aws_rds_cluster.school_db.endpoint}"
    db_username  = "admin"
    db_password  = "school_password"
    db_name      = "school_database"
  })]

depends_on = [kubectl_manifest.efs_pvc]
}
