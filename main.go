package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

// Dad jokes collection
var dadJokes = []string{
	"Why don't scientists trust atoms? Because they make up everything!",
	"What do you call a fake noodle? An impasta!",
	"Why did the scarecrow win an award? He was outstanding in his field!",
	"I used to hate facial hair, but then it grew on me.",
	"Why don't eggs tell jokes? They'd crack each other up!",
	"What do you call a bear with no teeth? A gummy bear!",
	"Why couldn't the bicycle stand up by itself? It was two tired!",
	"What did the ocean say to the beach? Nothing, it just waved!",
	"Why do fathers take an extra pair of socks to golf? In case they get a hole in one!",
	"How does a penguin build its house? Igloos it together!",
	"What did the janitor say when he jumped out of the closet? Supplies!",
	"Why did the math book look so sad? Because it had too many problems.",
	"What do you call cheese that isn't yours? Nacho cheese!",
	"Why can't you hear a psychiatrist using the bathroom? Because the 'p' is silent.",
	"What's the best thing about Switzerland? I don't know, but the flag is a big plus!",
	"Did you hear about the restaurant on the moon? Great food, no atmosphere.",
	"Why do chicken coops only have two doors? Because if they had four, they'd be chicken sedans!",
	"What do you call a fish wearing a bowtie? Sofishticated!",
	"How do you organize a space party? You planet!",
	"Why don't skeletons fight each other? They don't have the guts!",
}

func main() {
	// Seed random number generator
	rand.Seed(time.Now().UnixNano())

	// Check if we should run in HTTP mode (for cloud deployment)
	mode := os.Getenv("SERVER_MODE")
	if mode == "" {
		mode = "stdio" // Default to stdio for local/MCP use
	}

	// Create MCP server
	mcpServer := server.NewMCPServer(
		"demo-go",
		"0.0.1",
		server.WithToolCapabilities(true),
	)

	// Register tools
	registerTools(mcpServer)

	if mode == "http" {
		// Run HTTP server for cloud deployment
		port := os.Getenv("PORT")
		if port == "" {
			port = "8080"
		}
		log.Printf("Starting HTTP server on port %s", port)
		startHTTPServer(port, mcpServer)
	} else {
		// Run stdio server for local MCP use
		log.Println("Starting stdio MCP server")
		if err := server.ServeStdio(mcpServer); err != nil {
			log.Fatalf("Server error: %v", err)
		}
	}
}

func registerTools(mcpServer *server.MCPServer) {
	// Register a tool: add
	mcpServer.AddTool(
		mcp.NewTool("add",
			mcp.WithDescription("Add two integers: { a: int, b: int }"),
			mcp.WithNumber("a",
				mcp.Description("First integer"),
				mcp.Required(),
			),
			mcp.WithNumber("b",
				mcp.Description("Second integer"),
				mcp.Required(),
			),
		),
		func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
			args := req.GetArguments()
			a, ok1 := args["a"].(float64)
			b, ok2 := args["b"].(float64)
			if !ok1 || !ok2 {
				return nil, nil
			}
			sum := int(a) + int(b)
			return &mcp.CallToolResult{
				Content: []mcp.Content{
					mcp.TextContent{
						Type: "text",
						Text: strconv.Itoa(sum),
					},
				},
			}, nil
		},
	)

	// Register a tool: dad_joke
	mcpServer.AddTool(
		mcp.NewTool("dad_joke",
			mcp.WithDescription("Get a random dad joke to brighten your day"),
		),
		func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
			// Get a random joke
			joke := dadJokes[rand.Intn(len(dadJokes))]
			return &mcp.CallToolResult{
				Content: []mcp.Content{
					mcp.TextContent{
						Type: "text",
						Text: joke,
					},
				},
			}, nil
		},
	)
}

func startHTTPServer(port string, mcpServer *server.MCPServer) {
	// Create a new mux to avoid default handler matching issues
	mux := http.NewServeMux()

	// Add StreamableHTTP transport (recommended for MCP Inspector)
	streamableServer := server.NewStreamableHTTPServer(mcpServer,
		server.WithEndpointPath("/"),
	)

	// Mount streamableHTTP at root - it will handle requests to /
	// We need to wrap it to avoid conflicts with other handlers
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// If it's a specific path we handle elsewhere, skip
		if r.URL.Path == "/health" || r.URL.Path == "/ready" ||
			r.URL.Path == "/mcp" || r.URL.Path == "/api/joke" ||
			r.URL.Path == "/api/add" || r.URL.Path == "/sse" ||
			r.URL.Path == "/message" {
			// Let other handlers handle it
			http.NotFound(w, r)
			return
		}
		// Otherwise, let StreamableHTTP handle it
		streamableServer.ServeHTTP(w, r)
	})

	// Add SSE transport for backward compatibility
	sseServer := server.NewSSEServer(mcpServer,
		server.WithSSEEndpoint("/sse"),
		server.WithMessageEndpoint("/message"),
	)
	mux.Handle("/sse", sseServer.SSEHandler())
	mux.Handle("/message", sseServer.MessageHandler())

	// MCP JSON-RPC endpoint for tool discovery and execution
	mux.HandleFunc("/mcp", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Only POST method is allowed",
			})
			return
		}

		var jsonRPCReq map[string]interface{}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Failed to read request body",
			})
			return
		}

		if err := json.Unmarshal(body, &jsonRPCReq); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Invalid JSON-RPC request",
			})
			return
		}

		// Handle the request using the MCP server
		method, _ := jsonRPCReq["method"].(string)

		w.Header().Set("Content-Type", "application/json")

		switch method {
		case "tools/list":
			// List available tools
			id := jsonRPCReq["id"]
			tools := []map[string]interface{}{
				{
					"name":        "add",
					"description": "Add two integers",
					"inputSchema": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"a": map[string]interface{}{
								"type":        "number",
								"description": "First integer",
							},
							"b": map[string]interface{}{
								"type":        "number",
								"description": "Second integer",
							},
						},
						"required": []string{"a", "b"},
					},
				},
				{
					"name":        "dad_joke",
					"description": "Get a random dad joke to brighten your day",
					"inputSchema": map[string]interface{}{
						"type":       "object",
						"properties": map[string]interface{}{},
					},
				},
			}

			response := map[string]interface{}{
				"jsonrpc": "2.0",
				"id":      id,
				"result": map[string]interface{}{
					"tools": tools,
				},
			}
			json.NewEncoder(w).Encode(response)

		case "tools/call":
			// Call a tool
			id := jsonRPCReq["id"]
			params, _ := jsonRPCReq["params"].(map[string]interface{})
			toolName, _ := params["name"].(string)
			arguments, _ := params["arguments"].(map[string]interface{})

			// Execute the tool
			var result *mcp.CallToolResult

			switch toolName {
			case "add":
				a, ok1 := arguments["a"].(float64)
				b, ok2 := arguments["b"].(float64)
				if !ok1 || !ok2 {
					w.WriteHeader(http.StatusBadRequest)
					json.NewEncoder(w).Encode(map[string]interface{}{
						"jsonrpc": "2.0",
						"id":      id,
						"error": map[string]interface{}{
							"code":    -32602,
							"message": "Invalid parameters: a and b must be numbers",
						},
					})
					return
				}
				sum := int(a) + int(b)
				result = &mcp.CallToolResult{
					Content: []mcp.Content{
						mcp.TextContent{
							Type: "text",
							Text: strconv.Itoa(sum),
						},
					},
				}

			case "dad_joke":
				joke := dadJokes[rand.Intn(len(dadJokes))]
				result = &mcp.CallToolResult{
					Content: []mcp.Content{
						mcp.TextContent{
							Type: "text",
							Text: joke,
						},
					},
				}

			default:
				w.WriteHeader(http.StatusNotFound)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"jsonrpc": "2.0",
					"id":      id,
					"error": map[string]interface{}{
						"code":    -32601,
						"message": fmt.Sprintf("Tool not found: %s", toolName),
					},
				})
				return
			}

			response := map[string]interface{}{
				"jsonrpc": "2.0",
				"id":      id,
				"result": map[string]interface{}{
					"content": result.Content,
				},
			}
			json.NewEncoder(w).Encode(response)

		default:
			w.WriteHeader(http.StatusNotImplemented)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"jsonrpc": "2.0",
				"id":      jsonRPCReq["id"],
				"error": map[string]interface{}{
					"code":    -32601,
					"message": fmt.Sprintf("Method not found: %s", method),
				},
			})
		}
	})

	// Health check endpoint
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "healthy",
			"service": "mcp-demo-go",
			"version": "0.0.1",
			"time":    time.Now().UTC().Format(time.RFC3339),
		})
	})

	// Readiness endpoint
	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "ready",
		})
	})

	// API endpoint for getting a joke
	mux.HandleFunc("/api/joke", func(w http.ResponseWriter, r *http.Request) {
		joke := dadJokes[rand.Intn(len(dadJokes))]
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"joke": joke,
		})
	})

	// API endpoint for addition
	mux.HandleFunc("/api/add", func(w http.ResponseWriter, r *http.Request) {
		aStr := r.URL.Query().Get("a")
		bStr := r.URL.Query().Get("b")

		a, err1 := strconv.Atoi(aStr)
		b, err2 := strconv.Atoi(bStr)

		if err1 != nil || err2 != nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Invalid parameters. Use: /api/add?a=5&b=3",
			})
			return
		}

		sum := a + b
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]int{
			"a":      a,
			"b":      b,
			"result": sum,
		})
	})

	log.Printf("Server starting on http://localhost:%s", port)
	log.Printf("SSE endpoint: http://localhost:%s/sse", port)
	log.Printf("Message endpoint: http://localhost:%s/message", port)
	log.Printf("MCP JSON-RPC: http://localhost:%s/mcp", port)
	log.Printf("Health check: http://localhost:%s/health", port)
	log.Printf("Try: http://localhost:%s/api/joke", port)
	log.Printf("Try: http://localhost:%s/api/add?a=5&b=3", port)

	addr := fmt.Sprintf(":%s", port)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("HTTP server error: %v", err)
	}
}
