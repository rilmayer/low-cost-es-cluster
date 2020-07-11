# Low cost Elasticsearch cluster on GKE with ECK
About 25$/month.

## GCP settings
### Set your GCP account
```sh
GCP_PROJECT_ID=[YOUR GCP PROJECT ID]
gcloud config set project $GCP_PROJECT_ID
```

### Create service account for Terraform
```sh
# Create service account
gcloud iam service-accounts create terraform-serviceaccount \
  --display-name "Account for Terraform"

# Grant perimission to SA
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member serviceAccount:terraform-serviceaccount@$GCP_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/editor

# Get credencial file
ROOT_DIR_PATH=$(pwd)
GCP_CREDENCIAL_FILE_PATH="${ROOT_DIR_PATH}/terraform/sa.json"
gcloud iam service-accounts keys create $GCP_CREDENCIAL_FILE_PATH \
  --iam-account terraform-serviceaccount@$GCP_PROJECT_ID.iam.gserviceaccount.com

# Set credencial path
GOOGLE_CLOUD_KEYFILE_JSON=$GCP_CREDENCIAL_FILE_PATH
```

## Build GKE cluster
### Init
```sh
cd terraform
terraform init
```

### Apply terraform
GKE cluster will be created at `us-central1-a` region, because it is lower cost than other refgions as of June 2020.

```sh
terraform plan -var "project=${GCP_PROJECT_ID}"
terraform apply -var "project=${GCP_PROJECT_ID}"
```

### Destory resources
If you want to delete.
```sh
terraform destroy -var "project=${GCP_PROJECT_ID}"
```

## Build Elasticsearch cluster
If `spec:nodeSets:count:` is `1` in `elasticsearch.yaml`, it's single node structure.

### Get kubernetes credential
```sh
gcloud container clusters get-credentials es-cluster \
  --zone us-central1-a
```

### Install Elasticsearch Operator
```sh
# https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html
kubectl apply -f https://download.elastic.co/downloads/eck/1.1.0/all-in-one.yaml
kubectl -n elastic-system get all
```

### Apply Elasticsearch manifest
```sh
# Remove master taint (It's actually not good, but it enables to use all nodes)
# kubectl taint nodes --all node-role.kubernetes.io/master-

cd [ROOT DIR]
kubectl apply -f manifests/elasticsearch.yaml
```

### Confirm working
```sh
# Monitor cluster health
kubectl get elasticsearch

# Access to Elasticsearch
kubectl port-forward service/escluster-es-http 9200

# Request (From another shell)
PASSWORD=$(kubectl get secret escluster-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
curl -u "elastic:$PASSWORD" -k "https://localhost:9200"
```

## Deploy Kibana
### Apply kibana manifest
```sh
kubectl apply -f manifests/kibana.yaml
```

### Confirm working
```sh
# Monitor health
kubectl get kibana

# Access to Kibana
# Get password
kubectl get secret escluster-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode; echo
kubectl port-forward service/kibana-kb-http 5601
```

Access to `https://localhost:5601` with ID `elastic`

## Monitoring
Check `https://localhost:5601/app/monitoring`


## Enable to use external domain name
This is for hobby use. These are useful references.

- [Kubernetes: The Surprisingly Affordable Platform for Personal Projects](http://www.doxsey.net/blog/kubernetes--the-surprisingly-affordable-platform-for-personal-projects)
- [趣味GKEのIngressを無料で済ませる](https://livingalone.hatenablog.com/entry/2020/04/19/100000)

Following working are needed.

1. Get a domain and set Cloudflare (Above matrials are useful)
2. Realize the situation enabling to get IP from Domain by **kubernetes-Cloudflare-sync**
3. Make a component to manage L7 access by **Contour**
4. Set configs for realizing SSL by **Cert-manager**



### kubernetes-Cloudflare-sync
```sh
# Clone repository
git clone git@github.com:calebdoxsey/kubernetes-cloudflare-sync.git
cd kubernetes-cloudflare-sync

# Build image
GCP_PROJECT_ID=[YOUR_GCP_PROJECT_ID]
docker build -t gcr.io/${GCP_PROJECT_ID}/kubernetes-cloudflare-sync:latest .

# Push image
docker push gcr.io/${GCP_PROJECT_ID}/kubernetes-cloudflare-sync:latest

# Set configs
CLOUDFLARE_ACCOUNT_EMAIL=[YOUR_CLOUDFLARE_ACCOUNT_EMAIL_ADDRESS]
CLOUDFLARE_GLOBAL_API_KEY=[YOUR_CLOUDFLARE_GLOBAL_API_KEY]
kubectl create secret generic cloudflare \
  --from-literal=email=$CLOUDFLARE_ACCOUNT_EMAIL \
  --from-literal=api-key=$CLOUDFLARE_GLOBAL_API_KEY

# Create a clusterrolebinding
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user ${CLOUDFLARE_ACCOUNT_EMAIL}
```

Change configs to fit your settings, then apply like followings.

```sh
kubectl apply -f manifests/kubernetes-cloudflare-sync.yaml
```

### Contour
For deploying HTTPProxy.

```sh
# Prepare resources
git clone git@github.com:projectcontour/contour.git
cd contour
git checkout refs/tags/v1.3.0
```

Change configs like followings.

- `02-service-envoy.yaml`: Delete `type: LoadBalancer` and `externalTrafficPolicy: Local`
- `03-contour.yaml`: Add `--envoy-service-http-port=80` and `--envoy-service-https-port=443` in Contour serve commands
- `03-envoy.yaml`: Add `hostNetwork: true` and `dnsPolicy: ClusterFirstWithHostNet`

Then apply manifests.

```sh
kubectl apply -f examples/contour
```

### Cert-manager
```sh
# Install Cert-manager
#   https://cert-manager.io/docs/installation/kubernetes/
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager-legacy.yaml

# Check working
kubectl get pods --namespace cert-manager

# Generate cloudflare-api-key-secret
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-key-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-key: ${CLOUDFLARE_GLOBAL_API_KEY}
EOF

# Create the ClusterIssuer
cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${CLOUDFLARE_ACCOUNT_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - selector: {}
      dns01:
        cloudflare:
          email: ${CLOUDFLARE_ACCOUNT_EMAIL}
          apiKeySecretRef:
            name: cloudflare-api-key-secret
            key: api-key
EOF

# Create Certficate
DOMAIN_NAME="example.com"
cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: $(echo $DOMAIN_NAME | tr . -)
  namespace: default
spec:
  secretName: $(echo $DOMAIN_NAME | tr . -)
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - ${DOMAIN_NAME}
EOF
```

## Deploy HTTPProxy

```sh
cat << EOF | kubectl apply -f -
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: $(echo $DOMAIN_NAME | tr . -)
spec:
  virtualhost:
    fqdn: ${DOMAIN_NAME}
    tls:
      secretName: $(echo $DOMAIN_NAME | tr . -)
  routes:
    - services:
        - name: escluster-es-http
          port: 9200
      conditions:
        - prefix: /
EOF
```

Please access your domain with ID/PW.
