To install Flux without using the CLI, you can use Kubernetes manifests to deploy the necessary components. Here’s a step-by-step guide to installing Flux using manifests:

### 1. Create the Namespace

First, create a namespace for Flux to run in. You can use a manifest for this:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: flux-system
```

Apply the manifest:

```sh
kubectl apply -f namespace.yaml
```

### 2. Apply the Custom Resource Definitions (CRDs)

Flux requires several CRDs to function properly. You can download and apply the CRD manifests from the Flux GitHub repository:

```sh
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/crds.yaml
```

### 3. Create the Flux Custom Resources

Next, create the manifests for the Flux custom resources, such as `GitRepository`, `Kustomization`, etc. Here's an example of a minimal setup:

#### GitRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/your-org/your-repo
  ref:
    branch: main
  secretRef:
    name: flux-system
```

#### Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: "./clusters/my-cluster"
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
```

### 4. Apply the Custom Resources

Save these manifests to files (e.g., `gitrepository.yaml` and `kustomization.yaml`) and apply them:

```sh
kubectl apply -f gitrepository.yaml
kubectl apply -f kustomization.yaml
```

### 5. Deploy the Flux Controllers

Download and apply the Flux controllers manifest from the Flux GitHub repository:

```sh
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
```

### 6. (Optional) Create Secrets for Git Access

If your Git repository requires authentication, you need to create a Kubernetes secret. For example, to create a secret for SSH access:

```sh
kubectl create secret generic flux-system \
  --namespace=flux-system \
  --from-file=identity=<path-to-ssh-private-key> \
  --from-file=identity.pub=<path-to-ssh-public-key> \
  --from-file=known_hosts=<path-to-known-hosts>
```

Or for HTTPS access with a token:

```sh
kubectl create secret generic flux-system \
  --namespace=flux-system \
  --from-literal=username=<your-username> \
  --from-literal=password=<your-token>
```

### 7. Verify the Installation

Check the status of the Flux components to ensure they are running correctly:

```sh
kubectl get pods -n flux-system
```

You should see the Flux controllers running in the `flux-system` namespace.

### Summary

By following these steps, you can install Flux in your Kubernetes cluster using manifests instead of the CLI. This method gives you more control over the installation process and can be easily integrated into your GitOps workflows.To install Flux without using the CLI, you can use Kubernetes manifests to deploy the necessary components. Here’s a step-by-step guide to installing Flux using manifests:

### 1. Create the Namespace

First, create a namespace for Flux to run in. You can use a manifest for this:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: flux-system
```

Apply the manifest:

```sh
kubectl apply -f namespace.yaml
```

### 2. Apply the Custom Resource Definitions (CRDs)

Flux requires several CRDs to function properly. You can download and apply the CRD manifests from the Flux GitHub repository:

```sh
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/crds.yaml
```

### 3. Create the Flux Custom Resources

Next, create the manifests for the Flux custom resources, such as `GitRepository`, `Kustomization`, etc. Here's an example of a minimal setup:

#### GitRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/your-org/your-repo
  ref:
    branch: main
  secretRef:
    name: flux-system
```

#### Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: "./clusters/my-cluster"
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
```

### 4. Apply the Custom Resources

Save these manifests to files (e.g., `gitrepository.yaml` and `kustomization.yaml`) and apply them:

```sh
kubectl apply -f gitrepository.yaml
kubectl apply -f kustomization.yaml
```

### 5. Deploy the Flux Controllers

Download and apply the Flux controllers manifest from the Flux GitHub repository:

```sh
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
```

### 6. (Optional) Create Secrets for Git Access

If your Git repository requires authentication, you need to create a Kubernetes secret. For example, to create a secret for SSH access:

```sh
kubectl create secret generic flux-system \
  --namespace=flux-system \
  --from-file=identity=<path-to-ssh-private-key> \
  --from-file=identity.pub=<path-to-ssh-public-key> \
  --from-file=known_hosts=<path-to-known-hosts>
```

Or for HTTPS access with a token:

```sh
kubectl create secret generic flux-system \
  --namespace=flux-system \
  --from-literal=username=<your-username> \
  --from-literal=password=<your-token>
```

### 7. Verify the Installation

Check the status of the Flux components to ensure they are running correctly:

```sh
kubectl get pods -n flux-system
```

You should see the Flux controllers running in the `flux-system` namespace.

### Summary

By following these steps, you can install Flux in your Kubernetes cluster using manifests instead of the CLI. This method gives you more control over the installation process and can be easily integrated into your GitOps workflows.
