// Parameters file for deploying MCP Demo Go Server with API Management
// Use this to deploy the complete solution with API gateway

using './main.bicep'

// Container App configuration
param containerAppName = 'mcp-demo-go'
param containerImage = 'ghcr.io/ams0/mcp-demo-go:latest'

// Resource sizing
param cpuCore = '0.25'
param memorySize = '0.5Gi'

// Scaling configuration
param minReplicas = 1
param maxReplicas = 3

// API Management configuration
param deployApiManagement = true
param apimPublisherEmail = 'alessandro.vozza@linux.com' // Change this to your email
param apimPublisherName = 'Contoso Ltd' // Change this to your organization name
param apimSku = 'StandardV2'
param apimSkuCapacity = 1

// Tags
param tags = {
  application: 'mcp-demo-go'
  environment: 'production'
  managedBy: 'bicep'
  version: 'latest'
}
