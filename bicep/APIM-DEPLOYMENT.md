# Deploying with API Management

This guide explains how to deploy the MCP server with Azure API Management for API gateway capabilities, authentication, and rate limiting.

## Prerequisites

- Completed the basic deployment (see main README)
- Azure CLI logged in
- Existing resource group

## Quick Deploy with API Management

### 1. Update the parameters file

Edit `main-with-apim.bicepparam` and update:

```bicep
param apimPublisherEmail = 'your-email@domain.com'
param apimPublisherName = 'Your Organization Name'
```

### 2. Deploy

```bash
az deployment group create \
  --resource-group mcp-demo-rg \
  --template-file bicep/main.bicep \
  --parameters bicep/main-with-apim.bicepparam
```

**Note:** API Management deployment takes approximately 30-45 minutes for Consumption tier.

### 3. Get deployment outputs

```bash
# Get API Management gateway URL
az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.apimGatewayUrl.value \
  --output tsv

# Get developer portal URL
az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.apimDeveloperPortalUrl.value \
  --output tsv
```

## Retrieve API Key

After deployment, retrieve your subscription key:

```bash
# Get subscription ID
SUBSCRIPTION_ID=$(az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.apimSubscriptionId.value \
  --output tsv)

# Get subscription keys
az rest --method post \
  --uri "${SUBSCRIPTION_ID}/listSecrets?api-version=2023-05-01-preview" \
  --query "{primaryKey: primaryKey, secondaryKey: secondaryKey}"
```

Save the `primaryKey` for API calls.

## Using the API

### Base URL

```
https://<apim-name>.azure-api.net/mcp
```

### Authentication

All requests require the subscription key in the header:

```bash
# Using header (recommended)
curl -H "Ocp-Apim-Subscription-Key: <your-key>" \
  https://<apim-name>.azure-api.net/mcp/

# Using query parameter
curl "https://<apim-name>.azure-api.net/mcp/?subscription-key=<your-key>"
```

### Available Endpoints

#### 1. Service Info
```bash
curl -H "Ocp-Apim-Subscription-Key: <your-key>" \
  https://<apim-name>.azure-api.net/mcp/
```

#### 2. Health Check
```bash
curl -H "Ocp-Apim-Subscription-Key: <your-key>" \
  https://<apim-name>.azure-api.net/mcp/health
```

#### 3. Get Dad Joke
```bash
curl -H "Ocp-Apim-Subscription-Key: <your-key>" \
  https://<apim-name>.azure-api.net/mcp/api/joke
```

#### 4. Add Numbers
```bash
curl -H "Ocp-Apim-Subscription-Key: <your-key>" \
  "https://<apim-name>.azure-api.net/mcp/api/add?a=10&b=20"
```

## Developer Portal

### Accessing the Portal

Navigate to: `https://<apim-name>.developer.azure-api.net`

### User Registration and API Keys

1. **Self-Service Registration**:
   - Users can sign up at the developer portal
   - Email verification required
   - Auto-approval for subscriptions (configurable)

2. **Getting API Key**:
   - Sign in to developer portal
   - Go to "Products" → "MCP Demo Product"
   - Click "Subscribe"
   - View your subscription keys

3. **Managing Keys**:
   - Regenerate keys
   - View usage statistics
   - Test API directly in portal

## API Management Features

### Rate Limiting

Default: 100 calls per 60 seconds per subscription

To modify, edit the policy in `modules/api-management.bicep`:

```xml
<rate-limit calls="100" renewal-period="60" />
```

### CORS

Configured to allow all origins. To restrict:

```xml
<cors allow-credentials="false">
  <allowed-origins>
    <origin>https://yourdomain.com</origin>
  </allowed-origins>
</cors>
```

### Analytics

View API analytics in Azure Portal:
1. Go to API Management instance
2. Navigate to "Analytics"
3. View requests, performance, and errors

## Testing with curl

### Complete Example

```bash
# Set variables
APIM_NAME="apim-abc123def"
API_KEY="your-subscription-key-here"
BASE_URL="https://${APIM_NAME}.azure-api.net/mcp"

# Test all endpoints
echo "=== Service Info ==="
curl -H "Ocp-Apim-Subscription-Key: ${API_KEY}" ${BASE_URL}/

echo -e "\n\n=== Health Check ==="
curl -H "Ocp-Apim-Subscription-Key: ${API_KEY}" ${BASE_URL}/health

echo -e "\n\n=== Get Joke ==="
curl -H "Ocp-Apim-Subscription-Key: ${API_KEY}" ${BASE_URL}/api/joke

echo -e "\n\n=== Add Numbers ==="
curl -H "Ocp-Apim-Subscription-Key: ${API_KEY}" "${BASE_URL}/api/add?a=15&b=25"
```

### Without API Key (Expected Failure)

```bash
curl https://${APIM_NAME}.azure-api.net/mcp/api/joke
```

Response:
```json
{
  "statusCode": 401,
  "message": "Access denied due to missing subscription key."
}
```

## Advanced Configuration

### Custom Policies

Edit `modules/api-management.bicep` to add custom policies:

```xml
<policies>
  <inbound>
    <!-- Add IP filtering -->
    <ip-filter action="allow">
      <address-range from="1.2.3.4" to="1.2.3.4" />
    </ip-filter>
    
    <!-- Add request validation -->
    <validate-parameters specified-parameter-action="prevent" />
    
    <!-- Add caching -->
    <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" />
  </inbound>
</policies>
```

### Multiple Subscriptions

Create additional subscriptions for different users/teams:

```bash
az apim subscription create \
  --resource-group mcp-demo-rg \
  --service-name <apim-name> \
  --name team-a-subscription \
  --scope /products/mcp-demo-product \
  --display-name "Team A Subscription"
```

### Approval Required

To require manual approval for subscriptions, update the product:

```bicep
resource mcpProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  properties: {
    approvalRequired: true  // Change to true
    // ...
  }
}
```

## Monitoring and Troubleshooting

### View API Requests

```bash
# In Azure Portal
# API Management → APIs → MCP Demo API → Analytics
```

### Check Subscription Status

```bash
az apim subscription show \
  --resource-group mcp-demo-rg \
  --service-name <apim-name> \
  --subscription-id <subscription-id>
```

### Test API in Portal

1. Go to Azure Portal → API Management
2. Click "APIs" → "MCP Demo API"
3. Select an operation
4. Click "Test" tab
5. Add subscription key
6. Click "Send"

## Cost Considerations

### Consumption Tier
- Pay-per-execution model
- No upfront costs
- Best for development/testing
- ~$0.035 per 10,000 calls (first 1M calls free)

### Developer Tier
- ~$50/month
- Suitable for development/testing
- No SLA
- Single gateway unit

### Production Tiers
- Basic: ~$150/month
- Standard: ~$750/month
- Premium: ~$2,800/month
- Include SLA and premium features

## Clean Up

To remove API Management while keeping the Container App:

```bash
az deployment group create \
  --resource-group mcp-demo-rg \
  --template-file bicep/main.bicep \
  --parameters bicep/main.bicepparam
```

To remove everything:

```bash
az group delete --name mcp-demo-rg --yes --no-wait
```

## Next Steps

- Configure custom domains
- Set up Azure AD authentication
- Enable Application Insights
- Configure virtual network integration
- Set up CI/CD for API versioning

## Resources

- [API Management Documentation](https://learn.microsoft.com/azure/api-management/)
- [API Management Pricing](https://azure.microsoft.com/pricing/details/api-management/)
- [Policy Reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
