// Parameters file for deploying MCP Demo Go Server to Azure Container Apps
// Customize these values for your deployment

using './main.bicep'

// Container App configuration
param containerAppName = 'mcp-demo-go'
param containerImage = 'ghcr.io/ams0/mcp-demo-go:latest'

// Resource naming - will use default values with unique suffixes
// Uncomment and customize if needed:
// param environmentName = 'my-custom-env'
// param logAnalyticsName = 'my-custom-logs'

// Resource sizing
param cpuCore = '0.25'
param memorySize = '0.5Gi'

// Scaling configuration
param minReplicas = 1
param maxReplicas = 3

// Location - defaults to resource group location
// Uncomment to override:
// param location = 'eastus'

// Tags
param tags = {
  application: 'mcp-demo-go'
  environment: 'production'
  managedBy: 'bicep'
  version: 'latest'
}
