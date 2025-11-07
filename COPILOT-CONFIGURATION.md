# Configuring MCP Server with GitHub Copilot CLI

This guide shows how to add your MCP server (via Azure API Management) to GitHub Copilot CLI.

## Prerequisites

- GitHub Copilot CLI installed (`npm install -g @githubnext/github-copilot-cli`)
- Your API Management gateway URL and subscription key

## Your Configuration Details

**API Management Gateway URL:** `https://apim-kmpe2ejywixqg.azure-api.net`  
**API Subscription Key:** `YOUR_APIM_SUBSCRIPTION_KEY`  
**API Path:** `/mcp`

## Configuration Steps

### GitHub Copilot MCP Configuration

GitHub Copilot stores MCP server configurations in the `mcp-config.json` file.

**Location:** `~/.copilot/mcp-config.json`

Create or update the configuration file:

```json
{
  "mcpServers": {
    "mcp-demo-go": {
      "type": "http",
      "url": "https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "YOUR_APIM_SUBSCRIPTION_KEY"
      }
    }
  }
}
```

### Option 1: Using Command Line

```bash
# Create or update the MCP config file
cat > ~/.copilot/mcp-config.json << 'EOF'
{
  "mcpServers": {
    "mcp-demo-go": {
      "type": "http",
      "url": "https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "YOUR_APIM_SUBSCRIPTION_KEY"
      }
    }
  }
}
EOF

# Verify the file was created
cat ~/.copilot/mcp-config.json
```

### Option 2: Using Environment Variables

If you prefer environment variables:

```bash
# Add to your ~/.zshrc or ~/.bashrc
export MCP_SERVER_URL="https://apim-kmpe2ejywixqg.azure-api.net/mcp"
export MCP_API_KEY="YOUR_APIM_SUBSCRIPTION_KEY"
```

### Option 3: Using VS Code Settings (if using Copilot in VS Code)

**Location:** `~/Library/Application Support/Code - Insiders/User/settings.json` (macOS)  
Or: `~/.config/Code/User/settings.json` (Linux)  
Or: `%APPDATA%\Code\User\settings.json` (Windows)

```json
{
  "github.copilot.advanced": {
    "mcpServers": {
      "mcp-demo-go": {
        "type": "http",
        "url": "https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp",
        "headers": {
          "Ocp-Apim-Subscription-Key": "YOUR_APIM_SUBSCRIPTION_KEY"
        }
      }
    }
  }
}
```

## Quick Setup Command

```bash
# Create the MCP config file in the correct location
cat > ~/.copilot/mcp-config.json << 'EOF'
{
  "mcpServers": {
    "mcp-demo-go": {
      "type": "http",
      "url": "https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "YOUR_APIM_SUBSCRIPTION_KEY"
      }
    }
  }
}
EOF

# Verify the file was created
cat ~/.copilot/mcp-config.json
```

## Testing the Integration

### Test with curl

```bash
# Test MCP tool discovery
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_APIM_SUBSCRIPTION_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }' \
  https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp

# Test calling the add tool
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_APIM_SUBSCRIPTION_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "add",
      "arguments": {
        "a": 42,
        "b": 8
      }
    }
  }' \
  https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp

# Test calling the dad_joke tool
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_APIM_SUBSCRIPTION_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "dad_joke",
      "arguments": {}
    }
  }' \
  https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp
```

### Test with GitHub Copilot CLI

After configuration, restart your terminal and try:

```bash
# Ask Copilot to use the MCP server
gh copilot suggest "Tell me a joke using the MCP server"

# Or in interactive mode
gh copilot
```

The Copilot should be able to discover and use your MCP server's tools.

## Available Tools

Your MCP server provides these tools:

1. **add** - Add two integers
   - Parameters: `a` (integer), `b` (integer)
   - Example: `a=10, b=20` returns `30`

2. **dad_joke** - Get a random dad joke
   - No parameters required
   - Returns a random joke from the collection

## Verifying the Connection

Check if Copilot can see your MCP server:

```bash
# List available MCP servers (if supported by your Copilot version)
gh copilot config list

# Or check the logs
tail -f ~/.copilot/logs/copilot.log
```

## Troubleshooting

### Issue: "Unauthorized" or "Access Denied"

**Solution:** Verify your API key is correct:

```bash
SUBSCRIPTION_ID=$(az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.apimSubscriptionId.value \
  -o tsv)

az rest --method post \
  --uri "${SUBSCRIPTION_ID}/listSecrets?api-version=2023-05-01-preview" \
  --query "primaryKey" -o tsv
```

### Issue: "Connection Refused" or "Timeout"

**Solution:** Verify the API Management instance is running:

```bash
az apim show \
  --resource-group mcp-demo-rg \
  --name apim-kmpe2ejywixqg \
  --query provisioningState
```

### Issue: Copilot Not Finding the Server

**Solution:**
1. Verify the config file location: `~/.copilot/mcp-config.json`
2. Verify the config file syntax is valid JSON
3. Restart your terminal/IDE
4. Check Copilot version supports MCP (requires recent version)
5. Check logs: `~/.copilot/logs/`

### Issue: Rate Limiting

Your APIM is configured with 100 requests per 60 seconds. If you hit the limit:

```json
{
  "statusCode": 429,
  "message": "Rate limit is exceeded. Try again in 60 seconds."
}
```

**Solution:** Wait or increase the rate limit in the APIM policy.

## Security Best Practices

1. **Don't commit API keys** - Use environment variables or secure vaults
2. **Rotate keys regularly** - Generate new subscription keys periodically:
   ```bash
   az apim subscription regenerate-primary-key \
     --resource-group mcp-demo-rg \
     --service-name apim-kmpe2ejywixqg \
     --subscription-id <subscription-id>
   ```
3. **Monitor usage** - Check API Management analytics for unusual activity

## Advanced Configuration

### Custom Timeout

```json
{
  "mcpServers": {
    "mcp-demo-go": {
      "type": "http",
      "url": "https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "YOUR_APIM_SUBSCRIPTION_KEY"
      },
      "timeout": 30000
    }
  }
}
```

### Using Multiple MCP Servers

```json
{
  "mcpServers": {
    "mcp-demo-go": {
      "type": "http",
      "url": "https://apim-kmpe2ejywixqg.azure-api.net/mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "YOUR_APIM_SUBSCRIPTION_KEY"
      }
    },
    "another-server": {
      "type": "http",
      "url": "https://another-server.com/mcp",
      "headers": {
        "Authorization": "Bearer another-token"
      }
    }
  }
}
```



## API Management Benefits

By using API Management, you get:

- ✅ **Authentication** - API key protection
- ✅ **Rate Limiting** - 100 calls/60 seconds
- ✅ **Analytics** - Track usage in Azure Portal
- ✅ **Monitoring** - View performance metrics
- ✅ **Developer Portal** - Self-service API key management
- ✅ **Caching** - Improved performance (if configured)
- ✅ **Transformation** - Request/response manipulation
- ✅ **SLA** - 99.95% uptime guarantee (StandardV2)

## Next Steps

1. Share the API key with team members via secure channel
2. Set up additional subscriptions for different users/teams
3. Configure custom policies for advanced scenarios
4. Enable Application Insights for detailed telemetry
5. Set up alerts for rate limit or error thresholds

## Resources

- [GitHub Copilot CLI Documentation](https://github.com/github/github-copilot-cli)
- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io)
- [Azure API Management Documentation](https://learn.microsoft.com/azure/api-management/)
- [MCP Server Repository](https://github.com/ams0/mcp-demo-go)

## Getting Help

If you encounter issues:
1. Check the Azure Portal for APIM errors
2. Review Copilot logs: `~/.copilot/logs/`
3. Test the API directly with curl to isolate issues
4. Verify firewall/network settings allow HTTPS to Azure
