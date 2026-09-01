pipeline {
    agent {
        label 'k3s'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        REGISTRY     = 'localhost:5000'
        IMAGE_NAME   = 'is/11'
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
        RELEASE_NAME = 'webmethods11'
        DEPLOY_ENV   = 'dev'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Branch: ${env.GIT_BRANCH}, Commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Helm Lint') {
            steps {
                echo "Validating Helm chart syntax..."
                sh "helm lint ./helmchart"
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building Docker image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}..."
                sh """
                    docker build -f Dockerfile \
                        -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${REGISTRY}/${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Docker Push') {
            steps {
                echo "Pushing Docker image to ${REGISTRY}..."
                sh """
                    docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${REGISTRY}/${IMAGE_NAME}:latest
                """
            }
        }

        stage('Helm Deploy') {
            steps {
                echo "Deploying to Kubernetes with Helm..."
                sh """
                    if ! helm upgrade --install ${RELEASE_NAME} ./helmchart \
                        --set image.repository=${REGISTRY}/${IMAGE_NAME} \
                        --set image.tag=${IMAGE_TAG} \
                        --set env=${DEPLOY_ENV} \
                        --force \
                        --wait --timeout 3m; then
                        echo '[WARNING] Helm upgrade failed. Cleaning up potential HPA conflict...'
                        kubectl delete hpa webmethods11-app --ignore-not-found
                        helm upgrade --install ${RELEASE_NAME} ./helmchart \
                            --set image.repository=${REGISTRY}/${IMAGE_NAME} \
                            --set image.tag=${IMAGE_TAG} \
                            --set env=${DEPLOY_ENV} \
                            --force \
                            --wait --timeout 3m
                    fi
                """
            }
        }

        stage('Verify Rollout') {
            steps {
                echo "Verifying Deployment rollout..."
                sh "kubectl rollout status deployment/webmethods11-app --timeout=180s"
                sh "kubectl get pods -l app.kubernetes.io/name=webmethods11-app -o wide"
            }
        }

        stage('Smoke Test') {
            steps {
                echo "Executing Smoke Tests against MSR endpoints..."
                sh """
                    echo "Checking MSR Readiness Endpoint (Port 30555)..."
                    curl -s -f -o /dev/null -w "Readiness HTTP Status: %{http_code}\\n" http://localhost:30555/health/readiness
                    
                    echo "Checking MSR Liveness Endpoint (Port 30555)..."
                    curl -s -f -o /dev/null -w "Liveness HTTP Status: %{http_code}\\n" http://localhost:30555/health/liveness
                    
                    echo "All Smoke Tests passed successfully!"
                """
            }
        }
    }

    post {
        success {
            echo "Deploy SUCCESS - Image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "Deploy FAILED - Build #${env.BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}
