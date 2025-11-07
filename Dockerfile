# Multi-stage build for Go MCP server
FROM golang:1.25.3-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o mcp-server .

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1000 mcp && \
    adduser -D -u 1000 -G mcp mcp

WORKDIR /home/mcp

# Copy binary from builder
COPY --from=builder /app/mcp-server .

# Change ownership
RUN chown -R mcp:mcp /home/mcp

# Switch to non-root user
USER mcp

# Expose port for HTTP server (when running in cloud mode)
EXPOSE 8080

# The MCP server communicates via stdio by default
# Set SERVER_MODE=http to run as HTTP server in cloud environments
# Run the server
CMD ["./mcp-server"]
