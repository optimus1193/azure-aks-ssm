# Azure AKS Production Terraform Reference

This repo is designed as a secure production-grade reference implementation for Azure Kubernetes Service (AKS) in Terraform.

## Branch structure

This repository uses a single root module with reusable submodules for:
- network
- monitoring
- AKS

## Terraform version

```terraform
terraform {
  required_version = ">= 1.7.0"
}
```
