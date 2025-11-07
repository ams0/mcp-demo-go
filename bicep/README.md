# Azure Container Apps Deployment for MCP Demo Go Server

This directory contains Bicep templates to deploy the MCP Demo Go Server to Azure Container Apps.

## Architecture

The deployment creates the following resources:

- **Log Analytics Workspace**: Centralized logging and monitoring
- **Container Apps Environment**: Managed environment for hosting containers
- **Container App**: The MCP Demo Go Server running as a container

## Prerequisites

- Azure CLI (`az`) version 2.50.0 or higher
- An active Azure subscription
- Appropriate permissions to create resources in Azure
- Docker image pushed to a container registry (ghcr.io/ams0/mcp-demo-go:latest)

## Directory Structure

```
bicep/
├── main.bicep                          # Main orchestration template
├── main.bicepparam                     # Parameters file
├── modules/
│   ├── log-analytics.bicep            # Log Analytics Workspace
│   ├── container-apps-environment.bicep # Container Apps Environment
│   └── container-app.bicep            # Container App definition
└── README.md                          # This file
```

## Quick Start

### 1. Login to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2. Create a Resource Group

```bash
az group create \
  --name mcp-demo-rg \
  --location eastus
```

### 3. Deploy the Template

#### Option A: Using the parameters file

```bash
az deployment group create \
  --resource-group mcp-demo-rg \
  --template-file main.bicep \
  --parameters main.bicepparam
```

#### Option B: Using inline parameters

```bash
az deployment group create \
  --resource-group mcp-demo-rg \
  --template-file main.bicep \
  --parameters \
    containerAppName=mcp-demo-go \
    containerImage=ghcr.io/ams0/mcp-demo-go:latest \
    location=eastus
```

### 4. Validate Before Deployment (Recommended)

Preview changes before deployment:

```bash
az deployment group what-if \
  --resource-group mcp-demo-rg \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### 5. Get Deployment Outputs

```bash
az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs
```

## Customization

### Parameters

Edit `main.bicepparam` to customize the deployment:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `containerAppName` | Name of the Container App | `mcp-demo-go` |
| `containerImage` | Container image to deploy | `ghcr.io/ams0/mcp-demo-go:latest` |
| `cpuCore` | CPU cores (0.25-2.0) | `0.25` |
| `memorySize` | Memory allocation | `0.5Gi` |
| `minReplicas` | Minimum replicas | `1` |
| `maxReplicas` | Maximum replicas | `3` |
| `location` | Azure region | Resource group location |

### Environment Configuration

To modify the Container Apps Environment (e.g., add VNet integration, custom DNS):

Edit `modules/container-apps-environment.bicep`

### Container Configuration

To modify container settings (e.g., environment variables, secrets):

Edit `modules/container-app.bicep`

## Post-Deployment

### Access the Container App

Get the FQDN:

```bash
az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.containerAppFQDN.value \
  --output tsv
```

### View Logs

Stream logs from the container:

```bash
az containerapp logs show \
  --name mcp-demo-go \
  --resource-group mcp-demo-rg \
  --follow
```

### Monitor the Application

View logs in Log Analytics:

```bash
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'mcp-demo-go' | order by TimeGenerated desc | take 100"
```

## Scaling

### Manual Scaling

Update replica count:

```bash
az containerapp update \
  --name mcp-demo-go \
  --resource-group mcp-demo-rg \
  --min-replicas 2 \
  --max-replicas 5
```

### Auto-scaling

The template includes HTTP-based auto-scaling rules. Modify `modules/container-app.bicep` to adjust scaling behavior.

## Updating the Deployment

### Update Container Image

```bash
az containerapp update \
  --name mcp-demo-go \
  --resource-group mcp-demo-rg \
  --image ghcr.io/ams0/mcp-demo-go:v2
```

### Redeploy with Updated Bicep

```bash
az deployment group create \
  --resource-group mcp-demo-rg \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## Troubleshooting

### Check Container App Status

```bash
az containerapp show \
  --name mcp-demo-go \
  --resource-group mcp-demo-rg \
  --query properties.runningStatus
```

### View Revision History

```bash
az containerapp revision list \
  --name mcp-demo-go \
  --resource-group mcp-demo-rg \
  --output table
```

### Debug Container Issues

```bash
# Exec into the container (if enabled)
az containerapp exec \
  --name mcp-demo-go \
  --resource-group mcp-demo-rg \
  --command /bin/sh
```

## Security Considerations

- The deployment uses public container images from ghcr.io
- Ingress is set to external for health check purposes
- For production, consider:
  - Using managed identities for Azure Container Registry access
  - Implementing VNet integration
  - Enabling Azure DDoS Protection
  - Setting up Azure Front Door or Application Gateway
  - Configuring custom domains with SSL certificates

## Cost Optimization

- The deployment uses the Consumption workload profile (pay-per-use)
- Resources scale to zero when not in use (if `minReplicas = 0`)
- Log Analytics retention is set to 30 days (adjustable)

## Clean Up

Delete all resources:

```bash
az group delete --name mcp-demo-rg --yes --no-wait
```

## Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [MCP Protocol Documentation](https://modelcontextprotocol.io)

## Support

For issues related to:
- **MCP Server**: See main repository README
- **Azure Container Apps**: Refer to Azure documentation
- **Bicep Templates**: Check Bicep language reference
