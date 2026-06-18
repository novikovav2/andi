#!/bin/zsh
set -euo pipefail

echo "Create IAM token for auth docker in Yandex Cloud and login..."
yc iam create-token | docker login --username iam --password-stdin cr.yandex

echo "Creating timestamp variable..."
timestamp=$(date +"%Y%m%d%H%M%S")
image="cr.yandex/crp00fk6a8q59e1376d5/andi:v$timestamp"
echo "Timestamp variable: $timestamp"

echo "Building docker image..."
docker build .  --platform linux/amd64 -t "$image"
echo "OK"

echo "Pushing docker image to Yandex..."
docker push "$image"
echo "OK"

echo "Creating new container revision..."
yc serverless container revision deploy \
  --container-id bbauug32f5r713l1asua \
  --image "$image" \
  --service-account-id aje8gq2og579f8ca26fh \
  --memory 512MB \
  --cores 1 \
  --execution-timeout 30s \
  --concurrency 1 \
  --network-id enp974u433u8vtkiufgn \
  --min-instances 1 \
  --environment RAILS_LOG_TO_STDOUT=true \
  --environment RAILS_ENV=production \
  --environment YANDEX_CLOUD_FOLDER_ID=b1g2cpbba65drvdhjmnq \
  --environment SOLID_QUEUE_IN_PUMA=true \
  --environment RAILS_SERVE_STATIC_FILES=true \
  --environment YANDEX_STORAGE_BUCKET=andi \
  --secret environment-variable=YANDEX_STORAGE_ACCESS_KEY,key=YANDEX_STORAGE_ACCESS_KEY,id=e6q7geqf3lue8v1fuug5 \
  --secret environment-variable=DATABASE_URL,key=DATABASE_URL,id=e6q9r05mldq81p6dis6r \
  --secret environment-variable=RAILS_MASTER_KEY,key=RAILS_MASTER_KEY,id=e6qt4ru6hqa018b2dj3i \
  --secret environment-variable=YANDEX_STORAGE_SECRET_KEY,key=YANDEX_STORAGE_SECRET_KEY,id=e6qrg58rmudnpomd8fpp
 # --command 'bash' \
 # --args 'bin/rails db:migrate'
 echo "OK. Deploy completed"