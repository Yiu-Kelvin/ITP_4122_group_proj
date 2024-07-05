
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

resource "kubectl_manifest" "efs_storage_class" {
  yaml_body = <<YAML
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
YAML

  depends_on = [aws_eks_access_entry.access_entry, module.eks, 
  aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry]
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

  depends_on = [kubectl_manifest.efs_storage_class, module.eks, 
  aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry]
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
  depends_on = [kubectl_manifest.efs_storage_class, kubectl_manifest.efs_pv, module.eks, 
  aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry]
}

resource "kubectl_manifest" "cluster_role" {
    yaml_body = file("${path.root}/rbac/clusterRole.yaml")
  depends_on = [ aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry ]
}

resource "kubectl_manifest" "cluster_role_binding" {
    yaml_body = file("${path.root}/rbac/clusterRoleBinding.yaml")
  depends_on = [ aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry ]
}

resource "kubectl_manifest" "alb_ingress_controller_service_account" {
  yaml_body = templatefile("${path.root}/rbac/serviceAccount.yaml", {
    alb_ingress_controller_iam_role_arn = "${aws_iam_role.ALBIngressControllerRole.arn}"
  })
  
  depends_on = [ aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry ]
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
  depends_on = [module.eks, 
  aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry]
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
        name = "region"
        value = "${data.aws_region.current.name}"
    }

    set {
        name = "vpcId"
        value = module.vpc.vpc_id
    }

    depends_on = [kubectl_manifest.alb_ingress_controller_service_account, kubectl_manifest.ingressClass, module.eks, 
  aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry]
}

resource "helm_release" "latest" {
  name       = "latest"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "moodle"
  timeout    = 600
  values = [templatefile("values.yaml", {
    app_username = "${var.app_username}"
    app_password = "${var.app_password}"
    db_endpoint  = "${aws_rds_cluster.school_db.endpoint}"
    db_username  = "${var.db_username}"
    db_password  = "${var.db_password}"
    db_name      = "${var.db_name}"
    certificate_arn = "${aws_acm_certificate.cert.arn}"
  })]

  depends_on = [kubectl_manifest.efs_pvc, module.eks, 
  aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry]
}


resource "helm_release" "myportal" {
  name       = "myportal"
  repository = "oci://registry-1.docker.io/yiukelvin2005"
  chart      = "myportal_chart"
  timeout    = 600
  values = [templatefile("myportal_value.yaml", { 
    db_endpoint  = "${aws_rds_cluster.school_db.endpoint}"
    db_username  = "${var.db_username}"
    db_password  = "${var.db_password}"
    db_name      = "${var.db_name}"
    MICRO_CLIENT_ID = "${var.MICRO_CLIENT_ID}"
    MICRO_CLIENT_SECRET = "${var.MICRO_CLIENT_SECRET}"
  })]

  depends_on = [kubectl_manifest.efs_pvc, module.eks, 
  aws_eks_access_policy_association.admin, aws_eks_access_policy_association.cluster_admin, aws_eks_access_entry.access_entry]
}
