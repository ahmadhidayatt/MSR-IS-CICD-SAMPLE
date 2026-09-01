pipeline {
    agent {
        label 'k3s'
    }

    environment {
        REGISTRY     = 'localhost:5000'
        IMAGE_NAME   = 'is/11'
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
        RELEASE_NAME = 'webmethods11'
        // KUBECONFIG = credentials('k8s-kubeconfig') // Aktifkan jika pakai kubeconfig credentials di Jenkins
    }

    stages {
        stage('Docker Build') {
            steps {
                echo "Building Docker image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}..."
                sh """
                    docker build --no-cache -f Dockerfile \
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
                        --force-conflicts; then
                        echo '[WARNING] Helm upgrade failed. Cleaning up potential HPA conflict...'
                        kubectl delete hpa webmethods11-app --ignore-not-found
                        helm upgrade --install ${RELEASE_NAME} ./helmchart \
                            --set image.repository=${REGISTRY}/${IMAGE_NAME} \
                            --set image.tag=${IMAGE_TAG} \
                            --force-conflicts
                    fi
                """
            }
        }

        stage('Verify Rollout') {
            steps {
                echo "Verifying Deployment rollout status..."
                sh """
                    kubectl rollout status deployment/webmethods11-app --timeout=180s
                """
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
