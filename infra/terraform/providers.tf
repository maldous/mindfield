terraform {
  required_version = ">= 1.6.0"
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.13.2"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.2"
    }
    random = {
      source = "hashicorp/random"
      version = "3.6.2"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.5"
    }
    dotenv = {
      source = "jrhouston/dotenv"
      version = "~> 1.0"
    }
  }
}
provider "kubernetes" {
  config_path = var.kubeconfig
}
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
