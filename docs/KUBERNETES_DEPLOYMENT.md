# Kubernetes Deployment Guide

This guide provides instructions for deploying AI Architect on Kubernetes clusters. Kubernetes deployment is supported from version 1.3.0 onwards.

---

## Prerequisites

### Kubernetes cluster

A Kubernetes cluster must be available before deploying AI Architect. For production environments, ensure your cluster meets the following requirements:

**Required tools:**
- kubectl (Kubernetes command-line tool)
- helm (Kubernetes package manager)

### For testing and development

For testing purposes, you can create a local Kubernetes cluster using KIND (Kubernetes in Docker). KIND allows you to run Kubernetes clusters in Docker containers.

**Install KIND:**

**macOS:**
```bash
brew install kind kubectl helm
```

**Linux:**
```bash
# KIND
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Check Docker resources

Before creating a KIND cluster, verify Docker has sufficient resources:

```bash
docker info --format 'CPUs={{.NCPU}} Mem={{.MemTotal}}'
```

**Required:** Minimum 4 CPUs and 8GB RAM

If resources are insufficient, increase Docker Desktop resources (Preferences → Resources) and restart Docker.

---

## Setting up a test cluster with KIND

Create a KIND cluster with proper port mappings for service access:

```bash
kind create cluster --name bito-test --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
EOF
```

> **Note:** Services use ClusterIP for secure, internal-only access. External access is configured via Ingress Controller on ports 80/443.

### Verify cluster

```bash
kubectl cluster-info --context kind-bito-test
kubectl get nodes
```

---

## Deploying AI Architect on Kubernetes

### Step 1: Run setup

Navigate to your AI Architect installation directory and run the setup script:

```bash
cd /path/to/bito-ai-architect
./setup.sh
```

### Step 2: Select deployment type

When prompted, select **Kubernetes** as your deployment type.

### Step 3: Provide credentials

Provide the required credentials:
- Bito API key
- Git provider credentials
- LLM API keys (if not using Bito Enterprise Plan)

The setup script will automatically deploy AI Architect services to your Kubernetes cluster in the `bito-ai-architect` namespace.

---

## Verifying deployment

### Check service status

```bash
bitoarch status
```

### Check service health

```bash
bitoarch health
```

### Check pods

```bash
kubectl get pods -n bito-ai-architect
```

All pods should show `Running` status.

---

## Accessing services

Port-forwards are exposed on all network interfaces (0.0.0.0) and are accessible from any machine on the network.

### Local access (from the Kubernetes host machine)

```bash
curl http://localhost:5001/health          # Provider
curl http://localhost:5002/health          # Manager
curl http://localhost:5003/health          # Config
```

### Network access (from other machines on your network)

Get the host machine's IP address:

```bash
kubectl get nodes -o wide
# Or: hostname -I (Linux) / ifconfig (macOS)
```

From another machine on the network:

```bash
curl http://<host-ip>:5001/health          # Provider
curl http://<host-ip>:5002/health          # Manager
curl http://<host-ip>:5003/health          # Config
curl http://<host-ip>:5005/health          # Tracker
```

### MCP client configuration

Configure your MCP client (Cursor, Claude Desktop, etc.) to connect from any machine on the network:

```json
{
  "mcpServers": {
    "bito-ai-architect": {
      "url": "http://<host-ip>:5001/mcp",
      "apiKey": "<your-mcp-token>"
    }
  }
}
```

Replace `<host-ip>` with the Kubernetes host machine's IP address (e.g., 192.168.1.100).

### Security considerations

> **Important Security Notes:**
>
> - Port-forwards use HTTP (not HTTPS) - traffic is unencrypted
> - Services are accessible from any machine that can reach the host
>
> **For production internet-facing deployments:**
> - Use firewall rules to restrict access to trusted IPs
> - Consider using Kubernetes Ingress with TLS/SSL
> - Implement VPN for remote access
> - Use network policies to limit pod-to-pod traffic

### Alternative: Kubernetes Ingress (production)

For production deployments, configure a Kubernetes Ingress Controller with TLS/SSL instead of using port-forwards. This provides secure HTTPS access with proper certificate management.

---

## Viewing logs

### Live logs via kubectl

**Provider service:**
```bash
kubectl logs -n bito-ai-architect -l app.kubernetes.io/component=provider --tail=100 -f
```

**Manager service:**
```bash
kubectl logs -n bito-ai-architect -l app.kubernetes.io/component=manager --tail=100 -f
```

### Local log files

```bash
tail -f var/logs/cis-provider/provider.log
tail -f var/logs/cis-manager/manager.log
```

### Complete logs

```bash
./setup.sh --logs
```

---

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n bito-ai-architect
kubectl describe pod <pod-name> -n bito-ai-architect
```

### Access pod shell

```bash
kubectl exec -it -n bito-ai-architect \
  $(kubectl get pod -n bito-ai-architect -l app.kubernetes.io/component=provider -o jsonpath='{.items[0].metadata.name}') \
  -- /bin/sh
```

---

## Upgrading AI Architect

To upgrade to a newer version of AI Architect:

```bash
./upgrade.sh
```

The upgrade script automatically detects your Kubernetes deployment and performs the upgrade while preserving your data and configuration.

> **Important:** You can only upgrade within the same deployment type. To switch from Docker to Kubernetes or vice versa, you must use the `--clean` command, which will result in data loss.

---

## Uninstalling

### Remove deployment

```bash
./setup.sh --clean
```

This removes all AI Architect services and data from your cluster.

### Stop KIND cluster (preserves data)

```bash
docker stop bito-test-control-plane
```

### Delete KIND cluster completely

```bash
kind delete cluster --name bito-test
```

---
