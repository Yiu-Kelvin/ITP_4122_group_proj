
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

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}
data "aws_secretsmanager_secret" "secrets" {
  arn = "arn:aws:secretsmanager:us-east-1:891377140475:secret:myportal-yiD0AH"
}
data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
}

resource "kubernetes_secret" "myportal_secret" {
  metadata {
    name = "myportal-secret"
  }

  data = {
    MICRO_CLIENT_ID = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["MICRO_CLIENT_ID"]
    MICRO_CLIENT_SECRET = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["MICRO_CLIENT_SECRET"]
  }
  
  depends_on = [ module.eks, aws_eks_access_entry.access_entry ]
}

resource "kubectl_manifest" "efs_storage_class" {
  yaml_body = <<YAML
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
YAML

  depends_on = [module.eks, aws_eks_access_entry.access_entry]
}

resource "kubectl_manifest" "efs_pv" {
  yaml_body = <<YAML
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
    volumeHandle: ${var.efs_id}
YAML

  depends_on = [module.eks, kubectl_manifest.efs_storage_class, aws_eks_access_entry.access_entry]

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
  depends_on = [module.eks, kubectl_manifest.efs_pv, aws_eks_access_entry.access_entry]

}

resource "kubectl_manifest" "cluster_role" {
  yaml_body  = file("${path.root}/rbac/clusterRole.yaml")
  depends_on = [module.eks, aws_eks_access_entry.access_entry]

}

resource "kubectl_manifest" "cluster_role_binding" {
  yaml_body  = file("${path.root}/rbac/clusterRoleBinding.yaml")
  depends_on = [module.eks, aws_eks_access_entry.access_entry]

}

resource "kubectl_manifest" "alb_ingress_controller_service_account" {
  yaml_body = templatefile("${path.root}/rbac/serviceAccount.yaml", {
    alb_ingress_controller_iam_role_arn = "${aws_iam_role.ALBIngressControllerRole.arn}"
  })

  depends_on = [module.eks, aws_eks_access_entry.access_entry]

}
resource "kubectl_manifest" "ingressClass" {
  yaml_body  = <<YAML
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: ingress-class
spec:
  controller: ingress.k8s.aws/alb  
YAML
  depends_on = [module.eks, aws_eks_access_entry.access_entry]
}
resource "helm_release" "aws-load-balancer-controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "alb-ingress-controller"
  }

  set {
    name  = "region"
    value = data.aws_region.current.name
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [kubectl_manifest.alb_ingress_controller_service_account, kubectl_manifest.ingressClass, module.eks, aws_eks_access_entry.access_entry]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.8.4"

  values = [<<EOF
defaultArgs:
  - --cert-dir=/tmp
  - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
  - --kubelet-use-node-status-port
  - --metric-resolution=10s
EOF
  ]
  depends_on = [kubectl_manifest.alb_ingress_controller_service_account, kubectl_manifest.ingressClass, module.eks, aws_eks_access_entry.access_entry]

}

resource "helm_release" "latest" {
  name       = "latest"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "moodle"
  timeout    = 600
  values = [templatefile("values.yaml", {
    app_username    = "${var.app_username}"
    app_password    = "${var.app_password}"
    db_endpoint     = "${aws_rds_cluster.school_db.endpoint}"
    db_username     = "${var.db_username}"
    db_password     = "${var.db_password}"
    db_name         = "${var.db_name}"
    certificate_arn = "${aws_acm_certificate.cert.arn}"
  })]
  depends_on = [kubectl_manifest.efs_pvc, module.eks, aws_eks_access_entry.access_entry]
}


resource "helm_release" "myportal" {
  name       = "myportal"
  repository = "oci://registry-1.docker.io/yiukelvin2005"
  chart      = "myportal_chart"
  timeout    = 600
  values = [templatefile("myportal_value.yaml", {
    db_endpoint         = "${aws_rds_cluster.school_db.endpoint}"
    db_username         = "${var.db_username}"
    db_password         = "${var.db_password}"
    db_name             = "${var.db_name}"
  })]

  depends_on = [kubectl_manifest.efs_pvc, module.eks, kubernetes_secret.myportal_secret, aws_eks_access_entry.access_entry]
}

data "kubernetes_resources" "ingress" {
  api_version = "networking.k8s.io/v1"
  kind        = "Ingress"
  field_selector = "metadata.name=latest-moodle"
  depends_on = [ helm_release.latest , aws_eks_access_entry.access_entry]

} 