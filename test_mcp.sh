#!/bin/bash

# Test MCP server by sending JSON-RPC messages

echo "=== Initializing MCP Server ==="
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{"roots":{"listChanged":true},"sampling":{}},"clientInfo":{"name":"test-client","version":"1.0.0"}}}' | ./mcp-demo-go &
PID=$!
sleep 1

echo ""
echo "=== Listing Tools ==="
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | ./mcp-demo-go

echo ""
echo "=== Testing Calculator: 2+2 ==="
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add","arguments":{"operation":"add","a":2,"b":2}}}' | ./mcp-demo-go

# Clean up
kill $PID 2>/dev/null
wait $PID 2>/dev/null
