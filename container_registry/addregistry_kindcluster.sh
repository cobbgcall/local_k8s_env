#!/bin/sh
set -o errexit

# --- Configuration ---
REG_NAME='kind-registry'
REG_PORT='5001' # Host port for the registry
KIND_CLUSTER_NAME='kind-cluster' # Default Kind cluster name, change if yours is different
# --- End Configuration ---

echo "--- 1. Creating local Podman registry container (if not exists) ---"
if [ "$(podman inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != 'true' ]; then
  if [ "$(podman ps -a --filter name="^${REG_NAME}$" --format '{{.Names}}')" = "${REG_NAME}" ]; then
    echo "Registry container '${REG_NAME}' exists but is not running. Starting it."
    podman start "${REG_NAME}"
  else
    echo "Registry container '${REG_NAME}' does not exist. Creating it."
    podman run \
      -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --name "${REG_NAME}" \
      registry:2
  fi
else
  echo "Registry container '${REG_NAME}' is already running."
fi
echo "Registry '${REG_NAME}' is listening on 127.0.0.1:${REG_PORT}"
echo ""

echo "--- 2. Adding registry configuration to existing Kind nodes ---"
echo "This step assumes your Kind cluster nodes' containerd is configured to read from /etc/containerd/certs.d"
echo "For Kind v0.27.0+, this is often default. For older versions, the cluster needs to have been created with appropriate containerdConfigPatches."

REGISTRY_DIR="/etc/containerd/certs.d/localhost:${REG_PORT}"
# For Kind nodes, the registry will be accessible via its container name on the Podman 'kind' network
# The port inside the registry container is 5000.
NODE_REGISTRY_URL="http://${REG_NAME}:5000"

# Get nodes for the specified Kind cluster
NODES=$(kind get nodes --name "${KIND_CLUSTER_NAME}")
if [ -z "${NODES}" ]; then
  echo "Error: No nodes found for Kind cluster '${KIND_CLUSTER_NAME}'. Make sure the cluster exists and the name is correct."
  exit 1
fi

for node in ${NODES}; do
  echo "Configuring node: ${node}"
  podman exec "${node}" mkdir -p "${REGISTRY_DIR}"
  # The content for hosts.toml tells containerd how to reach the registry.
  # "localhost:${REG_PORT}" is the address Kubelet/containerd will try to pull from.
  # We map this to the actual service name of the registry container on the shared Docker network.
  # This configuration tells containerd that for image pulls from "localhost:${REG_PORT}",
  # it should actually connect to the registry service running at ${NODE_REGISTRY_URL}
  # (which is http://${REG_NAME}:5000, accessible from within the Kind node via the 'kind' Podman network).
  cat <<EOF | podman exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
server = "${NODE_REGISTRY_URL}"

[host."${NODE_REGISTRY_URL}"]
  capabilities = ["pull", "resolve"]
  # Since ${NODE_REGISTRY_URL} is an HTTP endpoint (http://${REG_NAME}:5000),
  # we need to indicate that TLS verification should be skipped or that it's an insecure registry.
  # For plain HTTP, skip_verify = true ensures containerd doesn't try to enforce HTTPS
  # or fail on what it might perceive as a misconfigured secure registry.
  skip_verify = true
EOF
  echo "Restarting containerd on node ${node} to apply changes..."
  podman exec "${node}" systemctl restart containerd
  # If systemctl is not available (e.g. some minimal node images),
  # a more forceful approach might be 'killall -1 containerd' or similar,
  # but 'systemctl restart' is preferred if available.
  # Alternatively, for some setups, no restart is needed and containerd picks it up.
  # If issues persist, a node reboot (kind delete node && kind create node, or cluster restart) might be a last resort.
done
echo "Registry configuration applied to Kind nodes."
echo ""

echo "--- 3. Connecting the registry to the Kind cluster network (if not already connected) ---"
KIND_NETWORK='kind' # Default Kind network name
if [ "$(podman inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REG_NAME}")" = 'null' ]; then
  echo "Connecting '${REG_NAME}' to network '${KIND_NETWORK}'..."
  if podman network inspect "${KIND_NETWORK}" > /dev/null 2>&1; then
    podman network connect "${KIND_NETWORK}" "${REG_NAME}"
    echo "'${REG_NAME}' connected to '${KIND_NETWORK}' network."
  else
    echo "Error: Podman network '${KIND_NETWORK}' not found. Cannot connect registry."
    echo "Ensure your Kind cluster is running and has created this network."
  fi
else
  echo "Registry '${REG_NAME}' is already connected to the '${KIND_NETWORK}' network."
fi
echo ""

echo "--- 4. Documenting the local registry in the cluster (kube-public ConfigMap) ---"
cat <<EOF | kubectl apply --context "kind-${KIND_CLUSTER_NAME}" -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
echo "ConfigMap 'local-registry-hosting' created/updated in 'kube-public' namespace."
echo ""

echo "--- Setup Complete ---"
echo "You should now be able to push images to localhost:${REG_PORT}/<image>:<tag>"
echo "And use them in your Kind cluster as localhost:${REG_PORT}/<image>:<tag>"
echo "Example:"
echo "  podman pull busybox"
echo "  podman tag busybox localhost:${REG_PORT}/my-busybox"
echo "  podman push localhost:${REG_PORT}/my-busybox"
echo "Then in your Kubernetes manifests:"
echo "  image: localhost:${REG_PORT}/my-busybox"
