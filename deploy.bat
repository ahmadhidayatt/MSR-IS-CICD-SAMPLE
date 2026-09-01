@echo off

echo Building Docker image...
docker build -f Dockerfile -t is/11 .
if %ERRORLEVEL% neq 0 goto :build_failed

echo Tagging Docker image...
docker tag is/11:latest localhost:5000/is/11:latest
if %ERRORLEVEL% neq 0 goto :tag_failed

echo Pushing Docker image...
docker push localhost:5000/is/11:latest
if %ERRORLEVEL% neq 0 goto :push_failed

:push_success
echo Navigating to helmchart directory...
pushd helmchart
if %ERRORLEVEL% neq 0 goto :cd_failed

echo Deploying with Helm...
helm upgrade --install webmethods11 . --force
if %ERRORLEVEL% equ 0 goto :helm_success

echo [WARNING] Helm upgrade failed. Attempting to resolve potential HPA conflict by deleting HPA webmethods11-app...
kubectl delete hpa webmethods11-app --ignore-not-found

echo Retrying Helm upgrade...
helm upgrade --install webmethods11 . --force
if %ERRORLEVEL% neq 0 goto :helm_failed

:helm_success
echo Restarting Kubernetes deployment...
kubectl rollout restart deployment webmethods11-app
if %ERRORLEVEL% neq 0 goto :rollout_failed

popd
echo Deployment completed successfully!
exit /b 0

:build_failed
echo [ERROR] Docker build failed with code %ERRORLEVEL%.
exit /b %ERRORLEVEL%

:tag_failed
echo [ERROR] Docker tag failed with code %ERRORLEVEL%.
exit /b %ERRORLEVEL%

:login_failed
echo [ERROR] AWS ECR login failed with code %ERRORLEVEL%.
exit /b %ERRORLEVEL%

:push_failed
echo [ERROR] Docker push failed with code %ERRORLEVEL%.
exit /b %ERRORLEVEL%

:cd_failed
echo [ERROR] Failed to navigate to helmchart directory.
exit /b 1

:helm_failed
echo [ERROR] Helm upgrade failed with code %ERRORLEVEL%.
popd
exit /b %ERRORLEVEL%

:rollout_failed
echo [ERROR] Kubectl rollout restart failed with code %ERRORLEVEL%.
popd
exit /b %ERRORLEVEL%
