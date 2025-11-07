// Log Analytics Workspace for Container Apps monitoring
// Provides centralized logging and monitoring capabilities

@description('Name of the Log Analytics Workspace')
param logAnalyticsName string

@description('Location for the Log Analytics Workspace')
param location string

@description('Tags to apply to the resource')
param tags object = {}

@description('Log retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

// Create Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Outputs
@description('The resource ID of the Log Analytics Workspace')
output workspaceId string = logAnalyticsWorkspace.properties.customerId

@description('The primary shared key of the Log Analytics Workspace')
output workspaceKey string = logAnalyticsWorkspace.listKeys().primarySharedKey

@description('The name of the Log Analytics Workspace')
output workspaceName string = logAnalyticsWorkspace.name

@description('The resource ID of the Log Analytics Workspace')
output resourceId string = logAnalyticsWorkspace.id
