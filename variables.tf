## Copyright (c) 2023, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.10.0"
    }
  }
  required_version = "= 1.2.9"
}

variable "compartment_ocid" {}

# 
variable "vcn_id" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type    = string
  default = ""
}


variable "vm_display_name" {
  type    = string
  default = "A10-GPU"
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "ad" {
  type    = string
  default = ""
}

variable "shape" {
  type    = string
  default = "VM.GPU.A10.1"
}


variable "use_existent_vcn" {
  type    = bool
  default = false
}

variable "vcn_name" {
  type    = string
  default = "GPU_VCN"
}


variable "vcn_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "dns_label" {
  type    = string
  default = "gpu"
}

variable "allow_ingress_from" {
  type    = string
  default = "0.0.0.0/0"
}

variable "operating_system" {
  description = "The operating system of the instance."
  type        = string
  default     = ""
}

variable "operating_system_version" {
  description = "The operating system version of the instance."
  type        = string
  default     = ""
}

variable customer_access_key {
  default = ""
  sensitive = true
}

variable customer_secret_key {
  default = ""
  sensitive = true
}

variable useExistingBucket {
  default = false
}