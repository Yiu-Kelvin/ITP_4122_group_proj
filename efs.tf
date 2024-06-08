resource "aws_efs_file_system" "moodle-volume" {
  creation_token = "moodle-volume"

  tags = {
    Name = "moodleVolume"
  }

}

resource "aws_efs_mount_target" "moodle-volume-aws_efs_mount_target-a" {
  file_system_id  = aws_efs_file_system.moodle-volume.id
  subnet_id       = module.vpc.private_subnets[0]
  security_groups = [module.eks.node_security_group_id, module.eks.cluster_security_group_id, module.eks.cluster_primary_security_group_id]
}

resource "aws_efs_mount_target" "moodle-volume-aws_efs_mount_target-b" {
  file_system_id  = aws_efs_file_system.moodle-volume.id
  subnet_id       = module.vpc.private_subnets[1]
  security_groups = [module.eks.node_security_group_id, module.eks.cluster_security_group_id, module.eks.cluster_primary_security_group_id]
}

