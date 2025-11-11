# MCP Server Demo Flow

This guide walks through building, deploying, and securing an MCP server from local development to production on Azure.

## Overview

The demo follows this progression:

1. **Local Development** - Build and test MCP server locally
2. **Local Client Connection** - Connect VS Code or Claude Desktop to local server
3. **Azure Deployment** - Deploy to Azure Container Apps (public, no auth)
4. **API Management** - Secure with Azure API Management
5. **Monitoring** - View metrics in Azure Monitor

## Prerequisites

- Go 1.25.3 or later
- Docker Desktop
- Azure CLI (`az`)
- VS Code or Claude Desktop
- Azure subscription

---

## Part 1: Local Development

### Step 1: Build the MCP Server

```bash
# Clone the repository
git clone https://github.com/ams0/mcp-demo-go.git
cd mcp-demo-go

# Install dependencies
go mod download

# Build the server
go build -o mcp-demo-go .
```

### Step 2: Test Locally with stdio

The MCP server runs in stdio mode by default:

```bash
# Run the server
./mcp-demo-go

# The server is now waiting for JSON-RPC messages on stdin
```

### Step 3: Test with MCP Inspector

Use the MCP Inspector to test your server:

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Run server with inspector
npx @modelcontextprotocol/inspector ./mcp-demo-go
```

This opens a web UI where you can:
- View available tools (`add`, `dad_joke`)
- Test tool execution
- See JSON-RPC message flow

### Step 4: Test Tools Manually

You can also pipe JSON-RPC directly:

```bash
# Test tools/list
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | ./mcp-demo-go

# Test add tool
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"add","arguments":{"a":10,"b":20}}}' | ./mcp-demo-go

# Test dad_joke tool
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"dad_joke","arguments":{}}}' | ./mcp-demo-go
```

---

## Part 2: Local Client Connection

### Option A: VS Code (Claude Desktop)

1. **Install Claude Desktop** (if not already installed)

2. **Configure MCP Server**

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "mcp-demo-go": {
      "command": "/Users/alessandro/repos/labs/mcp/mcp-demo-go/mcp-demo-go"
    }
  }
}
```

3. **Restart Claude Desktop**

4. **Test the Integration**

In Claude, ask:
```
Can you add 42 and 8 for me?
```

Claude should use the `add` tool from your MCP server.

```
Tell me a dad joke
```

Claude should use the `dad_joke` tool.

### Option B: Using Docker Locally

You can also run the server in Docker:

```bash
# Build Docker image
docker build -t mcp-demo-go:local .

# Run with stdio
docker run -i --rm mcp-demo-go:local
```

Update Claude config to use Docker:

```json
{
  "mcpServers": {
    "mcp-demo-go": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "mcp-demo-go:local"]
    }
  }
}
```

---

## Part 3: Azure Container Apps Deployment (No Auth)

### Step 1: Build and Push Docker Image

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build multi-platform image
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/ams0/mcp-demo-go:latest \
  --push .
```

### Step 2: Deploy to Azure (Basic Setup)

```bash
# Create resource group
az group create --name mcp-demo-rg --location eastus

# Deploy using basic Bicep (no APIM)
az deployment group create \
  --resource-group mcp-demo-rg \
  --template-file bicep/main.bicep \
  --parameters bicep/main.bicepparam
```

### Step 3: Get Container App URL

```bash
# Get the public URL
CONTAINER_APP_URL=$(az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.containerAppFQDN.value \
  -o tsv)

echo "Container App URL: https://${CONTAINER_APP_URL}"
```

### Step 4: Test Public Endpoint

The server runs in HTTP mode on Azure with multiple transports:

**Test JSON-RPC endpoint:**
```bash
curl -X POST https://${CONTAINER_APP_URL}/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }'
```

**Test with MCP Inspector:**
```bash
# MCP Inspector can connect via StreamableHTTP
# Open: https://inspector.modelcontextprotocol.io
# Enter URL: https://${CONTAINER_APP_URL}
```

**Test tools:**
```bash
# Test add tool
curl -X POST https://${CONTAINER_APP_URL}/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "add",
      "arguments": {"a": 100, "b": 50}
    }
  }'

# Test dad_joke tool
curl -X POST https://${CONTAINER_APP_URL}/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "dad_joke",
      "arguments": {}
    }
  }'
```

**⚠️ Security Note:** At this point, the API is **publicly accessible without authentication**. Anyone with the URL can use your MCP server.

---

## Part 4: Secure with API Management

### Step 1: Deploy API Management

```bash
# Deploy with APIM (this takes 30-40 minutes)
az deployment group create \
  --resource-group mcp-demo-rg \
  --template-file bicep/main.bicep \
  --parameters bicep/main-with-apim.bicepparam
```

### Step 2: Get APIM Details

```bash
# Get APIM Gateway URL
APIM_GATEWAY_URL=$(az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.apimGatewayUrl.value \
  -o tsv)

# Get Subscription Key
SUBSCRIPTION_ID=$(az deployment group show   --resource-group mcp-demo-rg   --name main  --query properties.outputs.apimSubscriptionId.value   --output tsv)

SUBSCRIPTION_KEY=$(az rest --method post  \
  --uri "${SUBSCRIPTION_ID}/listSecrets?api-version=2023-05-01-preview"  \
  --query "{primaryKey: primaryKey}" -o tsv)

echo "APIM Gateway: ${APIM_GATEWAY_URL}"
echo "Subscription Key: ${SUBSCRIPTION_KEY}"
```

### Step 3: Test Authenticated Endpoint

```bash
# Test with authentication
curl -X POST ${APIM_GATEWAY_URL}/mcp/mcp \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }'

# Test without authentication (should fail)
curl -X POST ${APIM_GATEWAY_URL}/mcp/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }'
```

### Step 4: Configure Client with Authentication

**Claude Desktop:**
```json
{
  "mcpServers": {
    "mcp-demo-go": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "YOUR_APIM_GATEWAY_URL/mcp/sse",
        "--header",
        "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY"
      ]
    }
  }
}
```

**GitHub Copilot CLI** (`~/.copilot/mcp-config.json`):
```json
{
  "mcpServers": {
    "mcp-demo-go": {
      "type": "sse",
      "url": "YOUR_APIM_GATEWAY_URL/mcp/sse",
      "headers": {
        "Ocp-Apim-Subscription-Key": "YOUR_SUBSCRIPTION_KEY"
      },
      "tools": []
    }
  }
}
```

### Step 5: What APIM Provides

- ✅ **Authentication** - API key required for all requests
- ✅ **Rate Limiting** - 100 calls per 60 seconds per subscription
- ✅ **Analytics** - Track usage and performance
- ✅ **Multiple Subscriptions** - Different keys for different users/teams
- ✅ **IP Filtering** - Can restrict by IP ranges (optional)
- ✅ **Throttling** - Protect backend from overload
- ✅ **Versioning** - Manage API versions
- ✅ **Developer Portal** - Self-service key management

---

## Part 5: Azure Monitor Metrics

### Step 1: View Container App Metrics

```bash
# Open Azure Portal
az portal
```

Navigate to: **Resource Group** → **mcp-demo-rg** → **Container App** → **Metrics**

**Key Metrics to Monitor:**

1. **Requests**
   - Total requests per second
   - Success vs failed requests

2. **Response Time**
   - Average response time
   - P95/P99 latency

3. **Replicas**
   - Active replica count
   - Scaling events

4. **CPU & Memory**
   - CPU usage percentage
   - Memory working set

5. **HTTP Status Codes**
   - 2xx (success)
   - 4xx (client errors)
   - 5xx (server errors)

### Step 2: View APIM Metrics

Navigate to: **API Management** → **Metrics**

**Key Metrics:**

1. **Requests**
   - Total API calls
   - Failed requests

2. **Capacity**
   - APIM capacity utilization

3. **Gateway Requests**
   - Successful vs failed

4. **Backend Duration**
   - Time spent waiting for Container App

### Step 3: Create Custom Dashboard

```bash
# Create a monitoring dashboard
az portal dashboard create \
  --resource-group mcp-demo-rg \
  --name mcp-demo-dashboard
```

Add these widgets:
- Container App request count
- Container App response time
- APIM request count
- APIM capacity
- Log Analytics query results

### Step 4: Query Logs

```bash
# Get Log Analytics Workspace ID
WORKSPACE_ID=$(az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.logAnalyticsWorkspaceId.value \
  -o tsv)
```

**Sample KQL Queries:**

**Request Count by Tool:**
```kql
ContainerAppConsoleLogs_CL
| where Log_s contains "tool_call"
| extend tool = extract('tool_name":"([^"]+)"', 1, Log_s)
| summarize Count=count() by tool, bin(TimeGenerated, 5m)
| render timechart
```

**Response Times:**
```kql
ContainerAppConsoleLogs_CL
| where Log_s contains "request_duration"
| extend duration = todouble(extract('duration_ms":([0-9.]+)', 1, Log_s))
| summarize avg(duration), percentile(duration, 95) by bin(TimeGenerated, 5m)
| render timechart
```

**Error Rate:**
```kql
ContainerAppConsoleLogs_CL
| where Log_s contains "error" or Log_s contains "failed"
| summarize ErrorCount=count() by bin(TimeGenerated, 5m)
| render timechart
```

### Step 5: Set Up Alerts

```bash
# Create action group for notifications
az monitor action-group create \
  --resource-group mcp-demo-rg \
  --name mcp-alerts \
  --short-name mcpalerts \
  --email-receiver name=admin email=your-email@example.com

# Create alert for high error rate
az monitor metrics alert create \
  --resource-group mcp-demo-rg \
  --name mcp-high-error-rate \
  --description "Alert when error rate exceeds 5%" \
  --scopes "$(az containerapp show -g mcp-demo-rg -n mcp-demo-go --query id -o tsv)" \
  --condition "avg Percentage of failed requests > 5" \
  --evaluation-frequency 5m \
  --window-size 15m \
  --action mcp-alerts
```

---

## Demo Script Summary

### Quick Demo Flow (15 minutes)

1. **Local (2 min)**
   ```bash
   go build && ./mcp-demo-go
   # Show stdio interaction
   ```

2. **Claude Desktop (2 min)**
   - Show configuration
   - Demonstrate tool usage in Claude

3. **Azure Deployment (3 min)**
   ```bash
   docker buildx build --push ...
   az deployment group create ...
   # Show public endpoint working
   ```

4. **API Management (3 min)**
   ```bash
   az deployment group create ... # with APIM
   # Show auth required
   # Show rate limiting
   ```

5. **Monitoring (5 min)**
   - Azure Portal metrics
   - Log Analytics queries
   - Custom dashboard

### Common Issues

**Issue: Container App not pulling latest image**
```bash
# Use version tags instead of :latest
VERSION=$(date +%Y%m%d-%H%M%S)
docker build -t ghcr.io/ams0/mcp-demo-go:${VERSION} --push .
az containerapp update --image ghcr.io/ams0/mcp-demo-go:${VERSION}
```

**Issue: APIM deployment timeout**
- APIM takes 30-40 minutes for initial deployment
- Use `--no-wait` flag and check status separately

**Issue: Claude Desktop not finding server**
- Verify config file location: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Check command path is absolute
- Restart Claude Desktop

---

## Cleanup

```bash
# Delete all Azure resources
az group delete --name mcp-demo-rg --yes --no-wait

# Check deletion status
az group exists --name mcp-demo-rg
```

---

## Next Steps

- Add more tools to your MCP server
- Implement custom policies in APIM (caching, transformation)
- Set up CI/CD with GitHub Actions
- Add Application Insights for deeper telemetry
- Implement custom authentication schemes
- Add multiple environments (dev/staging/prod)
