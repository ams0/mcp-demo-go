# MCP Demo Go Server

A demonstration Model Context Protocol (MCP) server written in Go that provides mathematical operations as tools.

## Overview

This MCP server implements a simple calculator tool that can add two integers. It demonstrates the core concepts of building an MCP server using the [mcp-go](https://github.com/mark3labs/mcp-go) library.

**Server Information:**
- **Name**: demo-go
- **Version**: 0.0.1
- **Protocol Version**: 2024-11-05

## Features

### Available Tools

#### `add`
Adds two integers together.

**Parameters:**
- `a` (number, required): First integer
- `b` (number, required): Second integer

**Returns:** The sum as text

**Example:**
```json
{
  "name": "add",
  "arguments": {
    "a": 5,
    "b": 3
  }
}
```
**Result:** `8`

## Prerequisites

- Go 1.21 or higher
- Node.js and npm (for MCP Inspector)

## Installation

### 1. Clone or navigate to the repository

```bash
cd /Users/alessandro/repos/labs/mcp/mcp-demo-go
```

### 2. Install dependencies

```bash
go mod download
```

### 3. Build the server

```bash
go build -o mcp-demo-go main.go
```

The executable `mcp-demo-go` will be created in the current directory.

## Usage

### Method 1: MCP Inspector (Recommended for Testing)

The MCP Inspector provides a visual web interface to interact with your MCP server.

```bash
npx @modelcontextprotocol/inspector ./mcp-demo-go
```

This will:
1. Start a local web server (usually at http://localhost:5173)
2. Launch your MCP server
3. Open a browser with an interactive UI where you can:
   - View all available tools
   - See tool descriptions and parameters
   - Test tools with custom inputs
   - View responses in real-time

### Method 2: Integration with Claude Desktop

To use this MCP server with Claude Desktop, add it to your configuration file.

**Location:** `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)

**Configuration:**
```json
{
  "mcpServers": {
    "demo-go": {
      "command": "/Users/alessandro/repos/labs/mcp/mcp-demo-go/mcp-demo-go"
    }
  }
}
```

After adding the configuration:
1. Restart Claude Desktop
2. The server will automatically connect
3. Claude will have access to the `add` tool

### Method 3: Manual Testing with JSON-RPC

You can interact with the server manually using JSON-RPC messages over stdio.

#### Create a test script (test_mcp.py):

```python
#!/usr/bin/env python3
import json
import subprocess

def send_request(proc, request):
    request_str = json.dumps(request) + "\n"
    proc.stdin.write(request_str.encode())
    proc.stdin.flush()
    
    response_line = proc.stdout.readline().decode()
    if response_line:
        return json.loads(response_line)
    return None

# Start the MCP server
proc = subprocess.Popen(
    ['./mcp-demo-go'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)

try:
    # Initialize
    init_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "test-client", "version": "1.0.0"}
        }
    }
    response = send_request(proc, init_request)
    print("Initialize:", json.dumps(response, indent=2))
    
    # Send initialized notification
    initialized = {"jsonrpc": "2.0", "method": "notifications/initialized"}
    proc.stdin.write((json.dumps(initialized) + "\n").encode())
    proc.stdin.flush()
    
    # List tools
    list_request = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    }
    response = send_request(proc, list_request)
    print("\nTools:", json.dumps(response, indent=2))
    
    # Call add tool
    call_request = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "add",
            "arguments": {"a": 10, "b": 20}
        }
    }
    response = send_request(proc, call_request)
    print("\nResult:", json.dumps(response, indent=2))
    
finally:
    proc.terminate()
    proc.wait()
```

Run the test:
```bash
python3 test_mcp.py
```

### Method 4: Using curl (for individual messages)

```bash
# Start the server
./mcp-demo-go &
SERVER_PID=$!

# Initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | ./mcp-demo-go

# List tools
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | ./mcp-demo-go

# Clean up
kill $SERVER_PID
```

## Development

### Project Structure

```
mcp-demo-go/
├── main.go           # Main server implementation
├── go.mod            # Go module dependencies
├── go.sum            # Dependency checksums
├── mcp-demo-go       # Compiled binary
└── README.md         # This file
```

### Adding New Tools

To add a new tool, follow this pattern in `main.go`:

```go
mcpServer.AddTool(
    mcp.NewTool("tool_name",
        mcp.WithDescription("Description of what the tool does"),
        mcp.WithString("param1",
            mcp.Description("Description of parameter"),
            mcp.Required(),
        ),
    ),
    func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
        args := req.GetArguments()
        param1 := args["param1"].(string)
        
        // Your tool logic here
        
        return &mcp.CallToolResult{
            Content: []mcp.Content{
                mcp.TextContent{
                    Type: "text",
                    Text: "result",
                },
            },
        }, nil
    },
)
```

### Parameter Types

The mcp-go library supports various parameter types:
- `mcp.WithString()` - String parameters
- `mcp.WithNumber()` - Numeric parameters
- `mcp.WithBoolean()` - Boolean parameters
- `mcp.WithArray()` - Array parameters
- `mcp.WithObject()` - Object parameters

### Building

```bash
# Build for current platform
go build -o mcp-demo-go main.go

# Build for specific platform
GOOS=linux GOARCH=amd64 go build -o mcp-demo-go-linux main.go
GOOS=darwin GOARCH=arm64 go build -o mcp-demo-go-macos main.go
GOOS=windows GOARCH=amd64 go build -o mcp-demo-go.exe main.go
```

### Building Docker Image (Multi-platform)

```bash
# Set your registry and image details
REGISTRY=ghcr.io/ams0
IMAGE=mcp-demo-go
TAG=latest

# Build and push multi-platform image (macOS with Docker Desktop)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t $REGISTRY/$IMAGE:$TAG \
  --push .
```

**Note:** Multi-platform builds require Docker Buildx. On macOS with Docker Desktop, this is enabled by default.

### Running in Development

```bash
# Run without building
go run main.go

# Run with race detector
go run -race main.go
```

## MCP Protocol

This server implements the Model Context Protocol, which enables communication between AI assistants and external tools via JSON-RPC over stdio.

### Key Concepts

1. **Initialization**: Client and server exchange capabilities
2. **Tools**: Functions that can be called by the AI
3. **JSON-RPC**: Communication protocol used for all messages
4. **Stdio Transport**: Messages are exchanged via standard input/output

### Message Flow

```
Client                          Server
  |                               |
  |---initialize----------------->|
  |<--capabilities----------------|
  |                               |
  |---notifications/initialized-->|
  |                               |
  |---tools/list----------------->|
  |<--tool definitions-----------|
  |                               |
  |---tools/call----------------->|
  |<--result---------------------|
```

## Troubleshooting

### Server doesn't start
- Ensure the binary has execute permissions: `chmod +x mcp-demo-go`
- Check that port 5173 is not in use (for MCP Inspector)
- Verify Go version: `go version`

### Tools not appearing in Claude Desktop
- Check the config file path is correct
- Ensure the absolute path to the binary is used
- Restart Claude Desktop after configuration changes
- Check Claude Desktop logs for errors

### JSON-RPC errors
- Ensure messages are properly formatted JSON
- Each message must end with a newline character
- Verify the protocol version matches (2024-11-05)

## Resources

- [Model Context Protocol Documentation](https://modelcontextprotocol.io)
- [MCP Go SDK](https://github.com/mark3labs/mcp-go)
- [MCP Specification](https://spec.modelcontextprotocol.io)
- [MCP Inspector](https://github.com/modelcontextprotocol/inspector)

## APIM troubleshooting (Container App backend)

If APIM calls time out but direct calls to the Container App FQDN work, configure APIM as follows:

- Backend `serviceUrl`: `https://mcp-demo-go.graywave-b3e914df.swedencentral.azurecontainerapps.io` (public FQDN, no trailing slash, no `/mcp`).
- API `path`: empty (`""`) so `/api/joke` maps cleanly.
- Operations: `GET /api/joke` (backend path `/api/joke`); for MCP JSON-RPC, add `POST /mcp` (backend path `/mcp`).
- Product: ensure the API is in a product that matches your subscription key and that the subscription is active.

Test via APIM (replace with your key):

```bash
curl -i --max-time 15 \
    -H "Ocp-Apim-Subscription-Key: <your key>" \
    https://aigwcloud.azure-api.net/api/joke
```

## APIM + Entra ID (JWT) authentication

Example working setup to secure this API via Entra ID and APIM:

- APIM `serviceUrl`: `https://mcp-demo-go.graywave-b3e914df.swedencentral.azurecontainerapps.io` (no trailing slash, no `/mcp`).
- API URL suffix: `entraid` ⇒ public base `https://aigwcloud.azure-api.net/entraid`.
- Operations: `GET /api/joke` (backend path `/api/joke`); add `POST /mcp` for JSON-RPC if needed.
- Subscription: optional; if disabled, only JWT is required. If enabled, send both JWT and subscription key.
- Entra app (API resource): `api://5e52ac77-93a5-49aa-923d-a1cdeb3e7cbf` as audience.

Inbound policy (APIM) used for validation:

```xml
<inbound>
    <base />
    <validate-jwt header-name="Authorization"
                                failed-validation-httpcode="401"
                                failed-validation-error-message="Unauthorized">
        <openid-config url="https://login.microsoftonline.com/2f88d75e-5ed4-41c4-9556-e627fd1ee262/v2.0/.well-known/openid-configuration" />
        <audiences>
            <audience>api://5e52ac77-93a5-49aa-923d-a1cdeb3e7cbf</audience>
        </audiences>
        <issuers>
            <issuer>https://sts.windows.net/2f88d75e-5ed4-41c4-9556-e627fd1ee262/</issuer>
        </issuers>
    </validate-jwt>
</inbound>
```

Getting a token (scope-based):

```bash
API_APP_ID=5e52ac77-93a5-49aa-923d-a1cdeb3e7cbf
TOKEN=$(az account get-access-token --scope api://$API_APP_ID/.default --query accessToken -o tsv)
```

Call through APIM (JWT only):

```bash
curl -i --max-time 15 \
    -H "Authorization: Bearer $TOKEN" \
    https://aigwcloud.azure-api.net/entraid/api/joke
```

If subscription is required, add: `-H "Ocp-Apim-Subscription-Key: <key>"`.

## License

This is a demonstration project for learning purposes.

## Contributing

Feel free to extend this demo by:
- Adding more mathematical operations (subtract, multiply, divide)
- Implementing error handling for edge cases
- Adding input validation
- Creating more complex tools

## Example Extension: Adding a Multiply Tool

```go
mcpServer.AddTool(
    mcp.NewTool("multiply",
        mcp.WithDescription("Multiply two numbers"),
        mcp.WithNumber("a",
            mcp.Description("First number"),
            mcp.Required(),
        ),
        mcp.WithNumber("b",
            mcp.Description("Second number"),
            mcp.Required(),
        ),
    ),
    func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
        args := req.GetArguments()
        a, ok1 := args["a"].(float64)
        b, ok2 := args["b"].(float64)
        if !ok1 || !ok2 {
            return mcp.NewToolResultError("Invalid arguments"), nil
        }
        product := a * b
        return &mcp.CallToolResult{
            Content: []mcp.Content{
                mcp.TextContent{
                    Type: "text",
                    Text: strconv.FormatFloat(product, 'f', -1, 64),
                },
            },
        }, nil
    },
)
```

## Questions?

For questions about:
- **MCP Protocol**: See [MCP Documentation](https://modelcontextprotocol.io)
- **Go SDK**: See [mcp-go GitHub](https://github.com/mark3labs/mcp-go)
- **This Demo**: Open an issue or modify the code to learn by doing!
