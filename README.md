# Low cost Elasticsearch cluster on GKE with ECK

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
  --zone asia-northeast1-a
```

### Installing the Elasticsearch Operator
```sh
kubectl apply -f https://download.elastic.co/downloads/eck/1.1.0/all-in-one.yaml
kubectl -n elastic-system get all
```

### Apply Elasticsearch manifest
```sh
# Remove master taint (It's actually not good, but it enables to use all nodes)
# kubectl taint nodes --all node-role.kubernetes.io/master-

cd manifests
kubectl apply -f elasticsearch.yaml
```

### Confirm working
```sh
# Monitor cluster health
kubectl get elasticsearch

# Access to Elasticsearch
kubectl port-forward service/escluster-es-http 9200

# Request (another shell)
PASSWORD=$(kubectl get secret escluster-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
curl -u "elastic:$PASSWORD" -k "https://localhost:9200"
```

## Deploy Kibana
### Apply kibana manifest
```sh
kubectl apply -f kibana.yaml
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

Access to `https://localhost:5601` with ID: `elastic`
