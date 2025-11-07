// API Management instance for MCP Demo Go Server
// Provides API gateway with authentication, rate limiting, and developer portal

@description('Name of the API Management instance')
param apimName string

@description('Location for API Management')
param location string

@description('Publisher email for API Management')
param publisherEmail string

@description('Publisher name for API Management')
param publisherName string

@description('SKU for API Management')
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
param apimSku string = 'StandardV2'

@description('SKU capacity (not applicable for Consumption tier, 1-10 for v2 SKUs)')
@minValue(0)
@maxValue(10)
param apimSkuCapacity int = 1

@description('Backend URL of the MCP server')
param backendUrl string

@description('Tags to apply to the resource')
param tags object = {}

// Create API Management instance
resource apimInstance 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: apimSku
    capacity: apimSku == 'Consumption' ? 0 : apimSkuCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    customProperties: {
      // Enable CORS for developer portal
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
    }
    // v2 SKUs support public network access control
    publicNetworkAccess: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Create backend for the MCP server
resource mcpBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  name: 'mcp-demo-backend'
  parent: apimInstance
  properties: {
    description: 'MCP Demo Go Server Backend'
    url: backendUrl
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// Create API for MCP server
resource mcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: 'mcp-demo-api'
  parent: apimInstance
  properties: {
    displayName: 'MCP Demo API'
    description: 'Model Context Protocol Demo Server API - provides math operations and dad jokes'
    path: 'mcp'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    serviceUrl: backendUrl
  }
}

// Define API operations - SSE endpoint for MCP Inspector
resource apiOperationSSE 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'mcp-sse'
  parent: mcpApi
  properties: {
    displayName: 'MCP SSE Connection'
    method: 'GET'
    urlTemplate: '/sse'
    description: 'Server-Sent Events endpoint for MCP Inspector and SSE-based clients'
    responses: [
      {
        statusCode: 200
        description: 'SSE stream'
        representations: [
          {
            contentType: 'text/event-stream'
          }
        ]
      }
    ]
  }
}

// Define API operations - Message endpoint for SSE
resource apiOperationMessage 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'mcp-message'
  parent: mcpApi
  properties: {
    displayName: 'MCP SSE Message'
    method: 'POST'
    urlTemplate: '/message'
    description: 'Message endpoint for SSE-based MCP communication'
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Message accepted'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Define API operations - MCP JSON-RPC endpoint
resource apiOperationMcp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'mcp-jsonrpc'
  parent: mcpApi
  properties: {
    displayName: 'MCP JSON-RPC'
    method: 'POST'
    urlTemplate: '/mcp'
    description: 'Model Context Protocol JSON-RPC endpoint for tool discovery and execution. Supports methods: tools/list, tools/call'
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'JSON-RPC response'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Define API operations - Root endpoint
resource apiOperationRoot 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'get-info'
  parent: mcpApi
  properties: {
    displayName: 'Get Service Info'
    method: 'GET'
    urlTemplate: '/'
    description: 'Get information about the MCP server and available endpoints'
    responses: [
      {
        statusCode: 200
        description: 'Service information'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Define API operations - Health check
resource apiOperationHealth 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'get-health'
  parent: mcpApi
  properties: {
    displayName: 'Health Check'
    method: 'GET'
    urlTemplate: '/health'
    description: 'Check the health status of the MCP server'
    responses: [
      {
        statusCode: 200
        description: 'Service is healthy'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Define API operations - Get joke
resource apiOperationJoke 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'get-joke'
  parent: mcpApi
  properties: {
    displayName: 'Get Dad Joke'
    method: 'GET'
    urlTemplate: '/api/joke'
    description: 'Get a random dad joke to brighten your day'
    responses: [
      {
        statusCode: 200
        description: 'A random dad joke'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Define API operations - Add numbers
resource apiOperationAdd 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'add-numbers'
  parent: mcpApi
  properties: {
    displayName: 'Add Two Numbers'
    method: 'GET'
    urlTemplate: '/api/add'
    description: 'Add two integers together. Use query parameters: ?a=5&b=3'
    request: {
      queryParameters: [
        {
          name: 'a'
          description: 'First number to add'
          type: 'integer'
          required: true
        }
        {
          name: 'b'
          description: 'Second number to add'
          type: 'integer'
          required: true
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Sum of the two numbers'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// API-level policy to set backend and configure CORS
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: mcpApi
  properties: {
    value: '''
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="mcp-demo-backend" />
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
    <rate-limit calls="100" renewal-period="60" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
    format: 'xml'
  }
  dependsOn: [
    mcpBackend
  ]
}

// Create a product for the API
resource mcpProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  name: 'mcp-demo-product'
  parent: apimInstance
  properties: {
    displayName: 'MCP Demo Product'
    description: 'Access to the MCP Demo API with rate limiting and monitoring'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
    terms: 'By subscribing to this product, you agree to use the API responsibly.'
  }
}

// Associate API with product
resource productApi 'Microsoft.ApiManagement/service/products/apis@2023-05-01-preview' = {
  name: 'mcp-demo-api'
  parent: mcpProduct
  dependsOn: [
    mcpApi
  ]
}

// Create a default subscription for testing
resource defaultSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: 'mcp-demo-subscription'
  parent: apimInstance
  properties: {
    displayName: 'MCP Demo Default Subscription'
    scope: '/products/${mcpProduct.id}'
    state: 'active'
  }
}

// Outputs
@description('The resource ID of the API Management instance')
output apimId string = apimInstance.id

@description('The name of the API Management instance')
output apimName string = apimInstance.name

@description('The gateway URL of the API Management instance')
output gatewayUrl string = apimInstance.properties.gatewayUrl

@description('The developer portal URL')
output developerPortalUrl string = 'https://${apimInstance.name}.developer.azure-api.net'

@description('The API path')
output apiPath string = mcpApi.properties.path

@description('The subscription ID for retrieving keys')
output subscriptionId string = defaultSubscription.id

@description('The subscription name')
output subscriptionName string = defaultSubscription.name

@description('The API Management principal ID for role assignments')
output principalId string = apimInstance.identity.principalId
