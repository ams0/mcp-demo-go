#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Deploy the MCP Demo Go server to Azure Container Apps using the repo's Bicep templates.

Usage:
  scripts/deploy_containerapp.sh \
    --resource-group <name> \
    [--location <azure-region>] \
    [--deployment-name <name>] \
    [--container-app-name <name>] \
    [--image <ghcr.io/...:tag>] \
    [--param-file <path>] \
    [--what-if] \
    [--test]

Notes:
- This script deploys the Container App + environment + Log Analytics.
- It does NOT deploy API Management (assumes you already have APIM).
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

RESOURCE_GROUP=""
LOCATION=""
DEPLOYMENT_NAME=""
CONTAINER_APP_NAME=""
IMAGE="ghcr.io/ams0/mcp-demo-go:latest"
PARAM_FILE="bicep/main.bicepparam"
DO_WHAT_IF="false"
DO_TEST="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group)
      RESOURCE_GROUP="$2"; shift 2;;
    --location)
      LOCATION="$2"; shift 2;;
    --deployment-name)
      DEPLOYMENT_NAME="$2"; shift 2;;
    --container-app-name)
      CONTAINER_APP_NAME="$2"; shift 2;;
    --image)
      IMAGE="$2"; shift 2;;
    --param-file)
      PARAM_FILE="$2"; shift 2;;
    --what-if)
      DO_WHAT_IF="true"; shift;;
    --test)
      DO_TEST="true"; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "--resource-group is required" >&2
  usage
  exit 1
fi

require_cmd az

# Ensure we're running from repo root so relative paths work.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f "bicep/main.bicep" ]]; then
  echo "Expected bicep/main.bicep in repo root: $REPO_ROOT" >&2
  exit 1
fi

if [[ ! -f "$PARAM_FILE" ]]; then
  echo "Param file not found: $PARAM_FILE" >&2
  exit 1
fi

# Check Azure auth early.
if ! az account show >/dev/null 2>&1; then
  echo "Not logged into Azure. Run: az login" >&2
  exit 1
fi

# Determine location (resource group location if not provided).
if [[ -z "$LOCATION" ]]; then
  if az group show -n "$RESOURCE_GROUP" >/dev/null 2>&1; then
    LOCATION="$(az group show -n "$RESOURCE_GROUP" --query location -o tsv)"
  else
    echo "Resource group '$RESOURCE_GROUP' does not exist and --location was not provided." >&2
    echo "Provide a location (example: --location eastus) so the script can create the resource group." >&2
    exit 1
  fi
fi

# Create RG if missing.
if ! az group show -n "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
fi

if [[ -z "$DEPLOYMENT_NAME" ]]; then
  DEPLOYMENT_NAME="mcp-demo-go-$(date +%Y%m%d-%H%M%S)"
fi

PARAM_OVERRIDES=(
  "containerImage=$IMAGE"
  "deployApiManagement=false"
)

if [[ -n "$CONTAINER_APP_NAME" ]]; then
  PARAM_OVERRIDES+=("containerAppName=$CONTAINER_APP_NAME")
fi

CMD_BASE=(
  az deployment group
)

if [[ "$DO_WHAT_IF" == "true" ]]; then
  echo "Running what-if (no changes applied)..."
  az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file bicep/main.bicep \
    --parameters "$PARAM_FILE" \
    --parameters "${PARAM_OVERRIDES[@]}"
  exit 0
fi

echo "Deploying to resource group '$RESOURCE_GROUP' (deployment: '$DEPLOYMENT_NAME')..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file bicep/main.bicep \
  --parameters "$PARAM_FILE" \
  --parameters "${PARAM_OVERRIDES[@]}" \
  --query "properties.outputs" \
  -o json > /tmp/mcp-demo-go-outputs.json

FQDN="$(python3 - <<'PY'
import json
with open('/tmp/mcp-demo-go-outputs.json','r',encoding='utf-8') as f:
    o=json.load(f)
print(o['containerAppFQDN']['value'])
PY
)"

echo "Container App URL: https://${FQDN}"

echo "Test JSON-RPC endpoint (tools/list):"
echo "  curl -X POST https://${FQDN}/mcp -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}'"

if [[ "$DO_TEST" == "true" ]]; then
  echo "Running smoke test..."
  curl -sS -X POST "https://${FQDN}/mcp" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | cat
  echo
fi
