pipeline {
    agent {
        label 'k3s'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        timestamps()
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

        stage('Docker Build') {
            steps {
                sh """
                    docker build -f Dockerfile \
                        -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${REGISTRY}/${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Docker Push') {
            steps {
                sh """
                    docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${REGISTRY}/${IMAGE_NAME}:latest
                """
            }
        }

        stage('Helm Deploy') {
            steps {
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

        stage('Verify') {
            steps {
                sh "kubectl rollout status deployment/webmethods11-app --timeout=180s"
                sh "kubectl get pods -l app.kubernetes.io/name=webmethods11-app -o wide"
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
