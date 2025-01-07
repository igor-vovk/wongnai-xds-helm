# Helm chart for [wongnai/xds](https://github.com/wongnai/xds)

Helm chart to ease the deployment of [wongnai/xds](https://github.com/wongnai/xds) GRPC XDS server to Kubernetes
clusters.

# Usage

Installing it manually:

```bash
helm repo add wongnai-xds https://igor-vovk.github.io/wongnai-xds-helm/
helm install wongnai-xds wongnai-xds/wongnai-xds
```

Installing it with ArgoCD:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: xds-server
  namespace: argocd
spec:
  project: default
  source:
    chart: wongnai-xds
    repoURL: https://igor-vovk.github.io/wongnai-xds-helm/
    targetRevision: 0.1.0
    helm:
      valuesObject:
  destination:
    server: https://kubernetes.default.svc
    namespace: xds-server
```

## Checking the deployment

Port-forward the port 9000 to your local machine and try opening it.
It should return the list of resources in the cluster.

## Exposing GRPC APIs to XDS server

This is described in [wongnai/xds documentation](https://github.com/wongnai/xds?tab=readme-ov-file#virtual-api-gateway).
Set up labels for your GRPC servers to publish information about GRPC APIs they expose:

```yaml
apiVersion: v1
kind: Service
metadata:
  # ...
  annotations:
    xds.lmwn.com/api-gateway: apigw1,apigw2
    xds.lmwn.com/grpc-service: package.name.ExampleService,package.name.Example2Service
```

## Setting up GRPC clients

By default, Helm chart creates a `xds-bootstrap-config` config map with `GRPC_XDS_BOOTSTRAP_CONFIG` environment
variable, which is everything that is needed to configure GRPC clients to use this XDS server.
You need to attach this config map to your services with GRPC clients like this:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: example-grpc-client

spec:
  selector:
    matchLabels:
      app: example-grpc-client
  template:
    spec:
      containers:
        - name: example-grpc-client
          image: example-grpc-client
          env:
            - name: GRPC_XDS_BOOTSTRAP_CONFIG
              valueFrom:
                configMapKeyRef:
                  name: xds-bootstrap-config
                  key: GRPC_XDS_BOOTSTRAP_CONFIG

```

or even simpler:

```yaml
#...
spec:
  template:
    spec:
      containers:
        - name: example-grpc-client
          image: example-grpc-client
          envFrom:
            - configMapRef:
                name: xds-bootstrap-config
```

This will configure your GRPC clients to use XDS server for name resolution process.
Then you should use`xds:///apigw1` address to connect to your GRPC servers, specifying gateways exposed in
`xds.lmwn.com/api-gateway` annotation.
