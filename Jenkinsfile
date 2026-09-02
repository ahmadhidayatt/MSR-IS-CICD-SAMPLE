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
        REGISTRY      = 'localhost:5000'
        IMAGE_NAME    = 'is/11'
        IMAGE_TAG     = "${env.BUILD_NUMBER}"
        TARGET_BRANCH = "${env.BRANCH_NAME ?: (env.GIT_BRANCH ? env.GIT_BRANCH.replace('origin/', '') : 'main')}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Target Branch : ${TARGET_BRANCH}"
                echo "Git Commit    : ${env.GIT_COMMIT}"
                echo "Build Tag     : ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
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

        stage('Deploy to DEV') {
            when {
                expression {
                    return (TARGET_BRANCH =~ /^rc/ || TARGET_BRANCH =~ /^dev/ || TARGET_BRANCH != 'main')
                }
            }
            environment {
                RELEASE_NAME = 'webmethods11'
                DEPLOY_ENV   = 'dev'
                NODE_PORT    = '30555'
            }
            steps {
                echo "========================================="
                echo ">>> Deploying to DEV Environment (${RELEASE_NAME}) <<<"
                echo "========================================="
                sh """
                    if ! helm upgrade --install ${RELEASE_NAME} ./helmchart \
                        --set image.repository=${REGISTRY}/${IMAGE_NAME} \
                        --set image.tag=${IMAGE_TAG} \
                        --set env=${DEPLOY_ENV} \
                        --set service.nodePort=${NODE_PORT} \
                        --force \
                        --wait --timeout 3m; then
                        echo '[WARNING] Helm upgrade failed. Cleaning up potential HPA conflict...'
                        kubectl delete hpa webmethods11-app --ignore-not-found
                        helm upgrade --install ${RELEASE_NAME} ./helmchart \
                            --set image.repository=${REGISTRY}/${IMAGE_NAME} \
                            --set image.tag=${IMAGE_TAG} \
                            --set env=${DEPLOY_ENV} \
                            --set service.nodePort=${NODE_PORT} \
                            --force \
                            --wait --timeout 3m
                    fi
                """
                echo "Verifying DEV deployment..."
                sh "kubectl rollout status deployment/webmethods11-app --timeout=180s"
                sh "kubectl get pods -l app.kubernetes.io/name=webmethods11-app -o wide"
                
                echo "Running Smoke Test on DEV (Port ${NODE_PORT})..."
                sh """
                    curl -s -f -o /dev/null -w "DEV Readiness HTTP Status: %{http_code}\\n" http://localhost:${NODE_PORT}/health/readiness
                    curl -s -f -o /dev/null -w "DEV Liveness HTTP Status: %{http_code}\\n" http://localhost:${NODE_PORT}/health/liveness
                    echo "DEV Smoke Test PASSED!"
                """
            }
        }

        stage('Deploy to PROD') {
            when {
                expression {
                    return (TARGET_BRANCH == 'main' || TARGET_BRANCH == 'master')
                }
            }
            environment {
                RELEASE_NAME = 'webmethods11'
                DEPLOY_ENV   = 'prod'
                NODE_PORT    = '30555'
            }
            steps {
                echo "========================================="
                echo ">>> Deploying to PROD Environment (${RELEASE_NAME}) <<<"
                echo "========================================="
                sh """
                    if ! helm upgrade --install ${RELEASE_NAME} ./helmchart \
                        --set image.repository=${REGISTRY}/${IMAGE_NAME} \
                        --set image.tag=${IMAGE_TAG} \
                        --set env=${DEPLOY_ENV} \
                        --set service.nodePort=${NODE_PORT} \
                        --force \
                        --wait --timeout 3m; then
                        echo '[WARNING] Helm upgrade failed. Cleaning up potential HPA conflict...'
                        kubectl delete hpa webmethods11-app --ignore-not-found
                        helm upgrade --install ${RELEASE_NAME} ./helmchart \
                            --set image.repository=${REGISTRY}/${IMAGE_NAME} \
                            --set image.tag=${IMAGE_TAG} \
                            --set env=${DEPLOY_ENV} \
                            --set service.nodePort=${NODE_PORT} \
                            --force \
                            --wait --timeout 3m
                    fi
                """
                echo "Verifying PROD deployment..."
                sh "kubectl rollout status deployment/webmethods11-app --timeout=180s"
                sh "kubectl get pods -l app.kubernetes.io/name=webmethods11-app -o wide"
                
                echo "Running Smoke Test on PROD (Port ${NODE_PORT})..."
                sh """
                    curl -s -f -o /dev/null -w "PROD Readiness HTTP Status: %{http_code}\\n" http://localhost:${NODE_PORT}/health/readiness
                    curl -s -f -o /dev/null -w "PROD Liveness HTTP Status: %{http_code}\\n" http://localhost:${NODE_PORT}/health/liveness
                    echo "PROD Smoke Test PASSED!"
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS for branch [${TARGET_BRANCH}] - Image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline FAILED for branch [${TARGET_BRANCH}] - Build #${env.BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}
