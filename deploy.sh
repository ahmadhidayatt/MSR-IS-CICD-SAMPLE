#!/usr/bin/env bash
set -e

echo "Building Docker image..."
docker build --no-cache -f Dockerfile -t is/11 .

echo "Tagging Docker image..."
docker tag is/11:latest localhost:5000/is/11:latest

echo "Pushing Docker image..."
docker push localhost:5000/is/11:latest

echo "Navigating to helmchart directory..."
pushd helmchart > /dev/null

echo "Deploying with Helm..."
if ! helm upgrade --install webmethods11 . --force-conflicts; then
    echo "[WARNING] Helm upgrade failed. Attempting to resolve potential HPA conflict by deleting HPA webmethods11-app..."
    kubectl delete hpa webmethods11-app --ignore-not-found
    echo "Retrying Helm upgrade..."
    helm upgrade --install webmethods11 . --force-conflicts
fi

echo "Restarting Kubernetes deployment..."
kubectl rollout restart deployment webmethods11-app

popd > /dev/null
echo "Deployment completed successfully!"
