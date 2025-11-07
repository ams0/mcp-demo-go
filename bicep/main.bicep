// Main Bicep template for deploying MCP Demo Go Server to Azure Container Apps
// This template creates all necessary resources including:
// - Log Analytics Workspace for monitoring
// - Container Apps Environment
// - Container App with the MCP server

targetScope = 'resourceGroup'

@description('Name of the Container App')
@minLength(2)
@maxLength(32)
param containerAppName string = 'mcp-demo-go'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container image to deploy')
param containerImage string = 'ghcr.io/ams0/mcp-demo-go:latest'

@description('Name of the Container Apps Environment')
param environmentName string = 'mcp-env-${uniqueString(resourceGroup().id)}'

@description('Name of the Log Analytics Workspace')
param logAnalyticsName string = 'mcp-logs-${uniqueString(resourceGroup().id)}'

@description('CPU cores allocated to the container (0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, or 2.0)')
param cpuCore string = '0.25'

@description('Memory allocated to the container')
param memorySize string = '0.5Gi'

@description('Minimum number of replicas')
@minValue(0)
@maxValue(30)
param minReplicas int = 1

@description('Maximum number of replicas')
@minValue(1)
@maxValue(30)
param maxReplicas int = 3

@description('Tags to apply to all resources')
param tags object = {
  application: 'mcp-demo-go'
  environment: 'production'
  managedBy: 'bicep'
}

@description('Deploy API Management instance')
param deployApiManagement bool = false

@description('API Management publisher email (required if deployApiManagement is true)')
param apimPublisherEmail string = ''

@description('API Management publisher name (required if deployApiManagement is true)')
param apimPublisherName string = ''

@description('API Management SKU')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'BasicV2'
  'Standard'
  'StandardV2'
  'Premium'
  'PremiumV2'
])
param apimSku string = 'Consumption'

@description('API Management SKU capacity (for v2 SKUs: 1-10 units)')
@minValue(0)
@maxValue(10)
param apimSkuCapacity int = 1

// Deploy Log Analytics Workspace for monitoring
module logAnalytics './modules/log-analytics.bicep' = {
  name: 'log-analytics-deployment'
  params: {
    logAnalyticsName: logAnalyticsName
    location: location
    tags: tags
  }
}

// Deploy Container Apps Environment
module environment './modules/container-apps-environment.bicep' = {
  name: 'environment-deployment'
  params: {
    environmentName: environmentName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsWorkspaceKey: logAnalytics.outputs.workspaceKey
    tags: tags
  }
}

// Deploy the Container App
module containerApp './modules/container-app.bicep' = {
  name: 'container-app-deployment'
  params: {
    containerAppName: containerAppName
    location: location
    environmentId: environment.outputs.environmentId
    containerImage: containerImage
    cpuCore: cpuCore
    memorySize: memorySize
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    tags: tags
  }
}

// Deploy API Management (optional)
module apiManagement './modules/api-management.bicep' = if (deployApiManagement) {
  name: 'api-management-deployment'
  params: {
    apimName: 'apim-${uniqueString(resourceGroup().id)}'
    location: location
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    apimSku: apimSku
    apimSkuCapacity: apimSkuCapacity
    backendUrl: 'https://${containerApp.outputs.fqdn}'
    tags: tags
  }
}

// Outputs
@description('The name of the Container App')
output containerAppName string = containerApp.outputs.containerAppName

@description('The FQDN of the Container App')
output containerAppFQDN string = containerApp.outputs.fqdn

@description('The name of the Container Apps Environment')
output environmentName string = environment.outputs.environmentName

@description('The name of the Log Analytics Workspace')
output logAnalyticsName string = logAnalytics.outputs.workspaceName

@description('The resource ID of the Container App')
output containerAppId string = containerApp.outputs.containerAppId

@description('The API Management gateway URL (if deployed)')
output apimGatewayUrl string = deployApiManagement ? apiManagement!.outputs.gatewayUrl : 'Not deployed'

@description('The API Management developer portal URL (if deployed)')
output apimDeveloperPortalUrl string = deployApiManagement ? apiManagement!.outputs.developerPortalUrl : 'Not deployed'

@description('The API Management API path (if deployed)')
output apimApiPath string = deployApiManagement ? apiManagement!.outputs.apiPath : 'Not deployed'

@description('The API Management subscription ID (if deployed)')
output apimSubscriptionId string = deployApiManagement ? apiManagement!.outputs.subscriptionId : 'Not deployed'
