// Container Apps Environment
// Provides the managed environment for hosting Container Apps with networking and observability

@description('Name of the Container Apps Environment')
param environmentName string

@description('Location for the Container Apps Environment')
param location string

@description('Log Analytics Workspace customer ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics Workspace shared key')
@secure()
param logAnalyticsWorkspaceKey string

@description('Tags to apply to the resource')
param tags object = {}

@description('Enable zone redundancy (requires supported region)')
param zoneRedundant bool = false

// Create Container Apps Environment
resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    // Configure app logs to send to Log Analytics
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceId
        sharedKey: logAnalyticsWorkspaceKey
      }
    }
    // Use consumption-based workload profile
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    zoneRedundant: zoneRedundant
  }
}

// Outputs
@description('The resource ID of the Container Apps Environment')
output environmentId string = environment.id

@description('The name of the Container Apps Environment')
output environmentName string = environment.name

@description('The default domain of the Container Apps Environment')
output defaultDomain string = environment.properties.defaultDomain
