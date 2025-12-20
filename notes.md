## JSON-RPC

curl -X POST https://mcp-demo-go.graywave-b3e914df.swedencentral.azurecontainerapps.io/mcp \
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

## HTTP

curl -X GET https://mcp-demo-go.graywave-b3e914df.swedencentral.azurecontainerapps.io/api/joke \
  -H "Content-Type: application/json"


curl -i --max-time 15 \
  -H "Ocp-Apim-Subscription-Key: 69c3e3d1279b4e8f9919033151228f82" \
  https://aigwcloud.azure-api.net/api/joke




## EntraID token

TOKEN=$(az account get-access-token --resource api://5e52ac77-93a5-49aa-923d-a1cdeb3e7cbf --query accessToken -o tsv)

curl -i --max-time 15 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Ocp-Apim-Trace: true" \
  -H "Ocp-Apim-Trace-Location: true" \
https://aigwcloud.azure-api.net/entraid/api/joke


## Expose as native MCP from UI


npx @modelcontextprotocol/inspector https://aigwcloud.azure-api.net/native-mcp-joke-server/mcp

curl -i --max-time 15 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  https://aigwcloud.azure-api.net/native-mcp-joke-server/mcp

(get a list of tools


curl -i --max-time 15 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id": 2,
    "method":"tools/call",
    "params":{
      "name":"joke",
      "arguments":{}
    }
  }' \
  -H "Ocp-Apim-Subscription-Key: 69c3e3d1279b4e8f9919033151228f82" https://aigwcloud.azure-api.net/native-mcp-joke-server/mcp)

