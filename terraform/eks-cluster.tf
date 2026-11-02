module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

   addons = {
    coredns                = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy             = {}
    vpc-cni                = {
      before_compute = true
    }
    aws-ebs-csi-driver = {}
  }
  
  name = "myapp-eks-cluster"
  kubernetes_version = "1.33"

  subnet_ids = module.myapp-vpc.private_subnets // outputs
  vpc_id = module.myapp-vpc.vpc_id # outputs

  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true


  eks_managed_node_groups = {
        dev = {  # name of the group
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t2.small"]

        min_size     = 1
        max_size     = 3
        desired_size = 3
        }
    }  

  tags = {
    environment = "development"
    applicaton = "myapp"
  }
}


module "aws_ebs_csi_pod_identity" {
source = "terraform-aws-modules/eks-pod-identity/aws"

name = "aws-ebs-csi"

attach_aws_ebs_csi_policy = true

associations = {
  this = {
    cluster_name = module.eks.cluster_name
    namespace = "kube-system"
    service_account = "ebs-csi-controller-sa"

  }

}

}


resource "null_resource" "configure_cluster" {

    triggers = {
        trigger_one = module.eks.cluster_name

    }

    provisioner "local-exec" {
        working_dir = "../ansible"
        command = "ansible-playbook ../ansible/deploy-kubernetes.yaml"
    }


}
