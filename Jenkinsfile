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
                echo "Target Branch : ${env.TARGET_BRANCH}"
                echo "Git Commit    : ${env.GIT_COMMIT}"
                echo "Build Tag     : ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
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
                echo "Building Docker image: ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}..."
                sh """
                    docker build -f Dockerfile \
                        -t ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG} \
                        -t ${env.REGISTRY}/${env.IMAGE_NAME}:latest .
                """
            }
        }

        stage('Docker Push') {
            steps {
                echo "Pushing Docker image to ${env.REGISTRY}..."
                sh """
                    docker push ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}
                    docker push ${env.REGISTRY}/${env.IMAGE_NAME}:latest
                """
            }
        }

        // ==========================================
        // 1. DEPLOY KE DEV (Branch rc* / dev / non-main)
        // ==========================================
        stage('Deploy to DEV') {
            when {
                expression {
                    return (env.TARGET_BRANCH =~ /^rc/ || env.TARGET_BRANCH =~ /^dev/ || env.TARGET_BRANCH != 'main')
                }
            }
            environment {
                RELEASE_NAME = 'webmethods11'
                DEPLOY_ENV   = 'dev'
                NODE_PORT    = '30555'
            }
            steps {
                echo "========================================="
                echo ">>> Deploying to DEV Environment (${env.RELEASE_NAME}) <<<"
                echo "========================================="
                sh """
                    if ! helm upgrade --install ${env.RELEASE_NAME} ./helmchart \
                        --set image.repository=${env.REGISTRY}/${env.IMAGE_NAME} \
                        --set image.tag=${env.IMAGE_TAG} \
                        --set env=${env.DEPLOY_ENV} \
                        --set service.nodePort=${env.NODE_PORT} \
                        --force \
                        --wait --timeout 3m; then
                        echo '[WARNING] Helm upgrade failed. Cleaning up potential HPA conflict...'
                        kubectl delete hpa webmethods11-app --ignore-not-found
                        helm upgrade --install ${env.RELEASE_NAME} ./helmchart \
                            --set image.repository=${env.REGISTRY}/${env.IMAGE_NAME} \
                            --set image.tag=${env.IMAGE_TAG} \
                            --set env=${env.DEPLOY_ENV} \
                            --set service.nodePort=${env.NODE_PORT} \
                            --force \
                            --wait --timeout 3m
                    fi
                """
                echo "Verifying DEV deployment..."
                sh "kubectl rollout status deployment/webmethods11-app --timeout=180s"
                sh "kubectl get pods -l app.kubernetes.io/name=webmethods11-app -o wide"
                
                echo "Running Smoke Test on DEV (Port ${env.NODE_PORT})..."
                sh """
                    curl -s -f -o /dev/null -w "DEV Readiness HTTP Status: %{http_code}\\n" http://localhost:${env.NODE_PORT}/health/readiness
                    curl -s -f -o /dev/null -w "DEV Liveness HTTP Status: %{http_code}\\n" http://localhost:${env.NODE_PORT}/health/liveness
                    echo "DEV Smoke Test PASSED!"
                """
            }
        }

        // ==========================================
        // 2. DEPLOY KE PROD (Branch main / master)
        // ==========================================
        stage('Deploy to PROD') {
            when {
                beforeInput true
                expression {
                    return (env.TARGET_BRANCH == 'main' || env.TARGET_BRANCH == 'master')
                }
            }
            input {
                message "Konfirmasi: Deploy image ke PRODUCTION?"
                ok "Approve & Deploy to PROD"
            }
            environment {
                RELEASE_NAME = 'webmethods11'
                DEPLOY_ENV   = 'prod'
                NODE_PORT    = '30555'
            }
            steps {
                echo "========================================="
                echo ">>> Deploying to PROD Environment (${env.RELEASE_NAME}) <<<"
                echo "========================================="
                sh """
                    if ! helm upgrade --install ${env.RELEASE_NAME} ./helmchart \
                        --set image.repository=${env.REGISTRY}/${env.IMAGE_NAME} \
                        --set image.tag=${env.IMAGE_TAG} \
                        --set env=${env.DEPLOY_ENV} \
                        --set service.nodePort=${env.NODE_PORT} \
                        --force \
                        --wait --timeout 3m; then
                        echo '[WARNING] Helm upgrade failed. Cleaning up potential HPA conflict...'
                        kubectl delete hpa webmethods11-app --ignore-not-found
                        helm upgrade --install ${env.RELEASE_NAME} ./helmchart \
                            --set image.repository=${env.REGISTRY}/${env.IMAGE_NAME} \
                            --set image.tag=${env.IMAGE_TAG} \
                            --set env=${env.DEPLOY_ENV} \
                            --set service.nodePort=${env.NODE_PORT} \
                            --force \
                            --wait --timeout 3m
                    fi
                """
                echo "Verifying PROD deployment..."
                sh "kubectl rollout status deployment/webmethods11-app --timeout=180s"
                sh "kubectl get pods -l app.kubernetes.io/name=webmethods11-app -o wide"
                
                echo "Running Smoke Test on PROD (Port ${env.NODE_PORT})..."
                sh """
                    curl -s -f -o /dev/null -w "PROD Readiness HTTP Status: %{http_code}\\n" http://localhost:${env.NODE_PORT}/health/readiness
                    curl -s -f -o /dev/null -w "PROD Liveness HTTP Status: %{http_code}\\n" http://localhost:${env.NODE_PORT}/health/liveness
                    echo "PROD Smoke Test PASSED!"
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS for branch [${env.TARGET_BRANCH}] - Image: ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
        }
        failure {
            echo "Pipeline FAILED for branch [${env.TARGET_BRANCH}] - Build #${env.BUILD_NUMBER}"
        }
        always {
            cleanWs()
        }
    }
}
