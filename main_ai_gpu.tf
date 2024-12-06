provider "oci" {}

data "oci_core_images" "gpu_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.operating_system
  operating_system_version = var.operating_system_version
  shape                    = var.shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "launch_mode"
    values = ["NATIVE"]
  }
#   filter {
#     name   = "display_name"
#     values = ["\\w*GPU\\w*"]
#     regex  = true
#   }
    filter {
      name   = "operating_system"
      values = ["Canonical Ubuntu", "Oracle Linux"]
    }

    # filter {
    #   name   = "operating_system_version"
    #   values = ["24.04", "8"]
    # }
}

locals {
  cloudinit_script = var.operating_system == "Oracle Linux" && var.operating_system_version == "8" ? "${path.module}/cloudinit.sh" : "${path.module}/cloudinit_ubuntu.sh"
}

resource "local_file" "cloudinit" {
  content  = file(local.cloudinit_script)
  filename = "${path.module}/cloudinit.sh"
  #file_permission = "0644"
}

data "cloudinit_config" "config" {
  gzip          = false
  base64_encode = true
  part {
    filename     = "/home/opc/cloudinit.sh"
    content_type = "text/x-shellscript"
    content = file(local.cloudinit_script)
  }
}

resource "oci_core_instance" "this" {
  agent_config {
    is_management_disabled = "false"
    is_monitoring_disabled = "false"
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Oracle Java Management Service"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "OS Management Service Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "OS Management Hub Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    is_live_migration_preferred = "false"
    recovery_action             = "RESTORE_INSTANCE"
  }

  availability_domain = var.ad
  compartment_id      = var.compartment_ocid

  create_vnic_details {
    assign_ipv6ip             = "false"
    assign_private_dns_record = "true"
    assign_public_ip = "true"
    subnet_id        = var.use_existent_vcn ? var.subnet_id : oci_core_subnet.subnets[0].id
  }

  display_name = var.vm_display_name

  instance_options {
    are_legacy_imds_endpoints_disabled = "false"
  }

  # does not works for BM
  is_pv_encryption_in_transit_enabled = length(regexall("BM", var.shape)) > 0 ? false : true

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.cloudinit_config.config.rendered
  }

  extended_metadata = {
    obj_storage_namespace   = module.object_storage.obj_storage_namespace
    bucket_name = module.object_storage.bucket_name
    customer_access_key = var.customer_access_key
    customer_secret_key = var.customer_secret_key
  }
  shape = var.shape
  source_details {
    boot_volume_size_in_gbs = "500"
    boot_volume_vpus_per_gb = "10"
    source_id = data.oci_core_images.gpu_images.images[0].id #local.ubuntu_image_id
    source_type = "image"
  }
  freeform_tags = { "GPU_TAG" = "A10-1" }

}

module "object_storage" {
 source = "./modules/object_storage"
 compartment_ocid = var.compartment_ocid
 useExistingBucket = var.useExistingBucket
}