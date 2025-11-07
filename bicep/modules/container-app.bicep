// Container App for MCP Demo Go Server
// Deploys the MCP server as a Container App with proper configuration

@description('Name of the Container App')
param containerAppName string

@description('Location for the Container App')
param location string

@description('Resource ID of the Container Apps Environment')
param environmentId string

@description('Container image to deploy')
param containerImage string

@description('CPU cores allocated to the container')
param cpuCore string = '0.25'

@description('Memory allocated to the container')
param memorySize string = '0.5Gi'

@description('Minimum number of replicas')
param minReplicas int = 1

@description('Maximum number of replicas')
param maxReplicas int = 3

@description('Tags to apply to the resource')
param tags object = {}

@description('Target port for ingress (MCP uses stdio, but we expose for health checks)')
param targetPort int = 8080

// Create Container App
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
    environmentId: environmentId
    configuration: {
      // Ingress configuration - external access for monitoring/health checks
      ingress: {
        external: true
        targetPort: targetPort
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      // Active revisions mode - use 'single' for standard deployments
      activeRevisionsMode: 'single'
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: containerImage
          resources: {
            cpu: json(cpuCore)
            memory: memorySize
          }
          env: [
            {
              name: 'SERVER_MODE'
              value: 'http'
            }
            {
              name: 'PORT'
              value: string(targetPort)
            }
          ]
          probes: [
            {
              type: 'liveness'
              httpGet: {
                path: '/health'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'readiness'
              httpGet: {
                path: '/ready'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// Outputs
@description('The resource ID of the Container App')
output containerAppId string = containerApp.id

@description('The name of the Container App')
output containerAppName string = containerApp.name

@description('The FQDN of the Container App')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The latest revision name')
output latestRevisionName string = containerApp.properties.latestRevisionName
