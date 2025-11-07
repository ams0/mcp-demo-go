# Cloud Deployment Changes

## Problem
The MCP server was terminating immediately in Azure Container Apps with exit code 0 because it only supported stdio mode, which exits after the initial connection when there's no stdin input.

## Solution
Modified the application to support **dual modes**:

### 1. **Stdio Mode (Default)** - For local MCP usage
- Used when `SERVER_MODE` environment variable is not set or set to `stdio`
- Maintains original MCP protocol functionality
- For use with MCP Inspector and Claude Desktop

### 2. **HTTP Mode** - For cloud deployment
- Activated when `SERVER_MODE=http` environment variable is set
- Runs a persistent HTTP server on port 8080
- Provides REST API endpoints for the same functionality

## Changes Made

### Modified Files

#### `main.go`
- Added HTTP server support with health/readiness endpoints
- Added REST API endpoints:
  - `GET /health` - Health check endpoint
  - `GET /ready` - Readiness probe endpoint
  - `GET /` - Service info
  - `GET /api/joke` - Get a random dad joke
  - `GET /api/add?a=5&b=3` - Add two numbers
- Reads `SERVER_MODE` and `PORT` environment variables
- Maintains backward compatibility with stdio mode

#### `Dockerfile`
- Added `EXPOSE 8080` directive
- Updated comments to reflect dual-mode support

#### `bicep/modules/container-app.bicep`
- Added environment variables:
  - `SERVER_MODE=http` - Activates HTTP mode
  - `PORT=8080` - Specifies listening port
- Added health probes:
  - **Liveness probe**: `/health` endpoint
  - **Readiness probe**: `/ready` endpoint
- Container now stays running and responds to health checks

## How to Use

### Local (Stdio Mode)
```bash
# No environment variable needed
./mcp-demo-go

# Or explicitly set stdio mode
SERVER_MODE=stdio ./mcp-demo-go
```

### Cloud/HTTP Mode
```bash
# Set HTTP mode
SERVER_MODE=http ./mcp-demo-go

# Or with custom port
SERVER_MODE=http PORT=3000 ./mcp-demo-go
```

### Docker
```bash
# Stdio mode
docker run -i ghcr.io/ams0/mcp-demo-go:latest

# HTTP mode
docker run -p 8080:8080 -e SERVER_MODE=http ghcr.io/ams0/mcp-demo-go:latest
```

### Azure Container Apps
The Bicep template automatically sets `SERVER_MODE=http`, so the container runs in HTTP mode with health checks.

## API Endpoints (HTTP Mode)

- `GET /` - Service information and available endpoints
- `GET /health` - Health check (returns {"status": "healthy", ...})
- `GET /ready` - Readiness check (returns {"status": "ready"})
- `GET /api/joke` - Get a random dad joke
- `GET /api/add?a=5&b=3` - Add two numbers

## Testing

### Test Locally with HTTP Mode
```bash
# Run in HTTP mode
SERVER_MODE=http go run main.go

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/api/joke
curl http://localhost:8080/api/add?a=10&b=20
```

### Test in Azure
After deployment completes:
```bash
# Get the FQDN
FQDN=$(az deployment group show \
  --resource-group mcp-demo-rg \
  --name main \
  --query properties.outputs.containerAppFQDN.value \
  --output tsv)

# Test endpoints
curl https://$FQDN/health
curl https://$FQDN/api/joke
curl https://$FQDN/api/add?a=5&b=3
```

## Deployment Steps

1. **Build and push the updated image:**
   ```bash
   docker buildx build \
     --platform linux/amd64,linux/arm64 \
     -t ghcr.io/ams0/mcp-demo-go:latest \
     --push .
   ```

2. **Deploy to Azure:**
   ```bash
   az deployment group create \
     --resource-group mcp-demo-rg \
     --template-file bicep/main.bicep \
     --parameters bicep/main.bicepparam
   ```

3. **Verify deployment:**
   ```bash
   az containerapp show \
     --name mcp-demo-go \
     --resource-group mcp-demo-rg \
     --query properties.runningStatus
   ```

## Benefits

✅ Container stays running in cloud environments
✅ Proper health checks for Container Apps
✅ Auto-scaling works correctly
✅ HTTP API accessible for testing
✅ Maintains backward compatibility with stdio mode
✅ No breaking changes to existing local usage
