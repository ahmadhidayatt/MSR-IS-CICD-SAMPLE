pipeline {
    agent { label 'k3s' }

    options {
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        REGISTRY      = 'localhost:5000'
        IMAGE_NAME    = 'is/11'
        IMAGE_TAG     = "${env.BUILD_NUMBER}"
        RELEASE_NAME  = 'webmethods11'
        NODE_PORT     = '30555'
        TARGET_BRANCH = "${env.BRANCH_NAME ?: (env.GIT_BRANCH ? env.GIT_BRANCH.replace('origin/', '') : 'main')}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Helm Lint') {
            steps {
                sh "helm lint ./helmchart"
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build -f Dockerfile \
                        -t ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG} \
                        -t ${env.REGISTRY}/${env.IMAGE_NAME}:latest .
                """
            }
        }

        stage('Docker Push') {
            steps {
                sh """
                    docker push ${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}
                    docker push ${env.REGISTRY}/${env.IMAGE_NAME}:latest
                """
            }
        }

        stage('Deploy DEV') {
            when {
                expression {
                    return (env.TARGET_BRANCH =~ /^rc/ || env.TARGET_BRANCH =~ /^dev/ || env.TARGET_BRANCH != 'main')
                }
            }
            steps {
                sh """
                    helm upgrade --install ${env.RELEASE_NAME} ./helmchart \
                        --set image.repository=${env.REGISTRY}/${env.IMAGE_NAME} \
                        --set image.tag=${env.IMAGE_TAG} \
                        --set env=dev \
                        --set service.nodePort=${env.NODE_PORT}
                    kubectl rollout status deployment/${env.RELEASE_NAME}-app --timeout=360s
                    curl -sf http://localhost:${env.NODE_PORT}/health/readiness
                    curl -sf http://localhost:${env.NODE_PORT}/health/liveness
                """
            }
        }

        stage('Deploy PROD') {
            when {
                beforeInput true
                expression {
                    return (env.TARGET_BRANCH == 'main' || env.TARGET_BRANCH == 'master')
                }
            }
            input {
                message "Deploy to PRODUCTION?"
                ok "Deploy"
            }
            steps {
                sh """
                    helm upgrade --install ${env.RELEASE_NAME} ./helmchart \
                        --set image.repository=${env.REGISTRY}/${env.IMAGE_NAME} \
                        --set image.tag=${env.IMAGE_TAG} \
                        --set env=prod \
                        --set service.nodePort=${env.NODE_PORT}
                    kubectl rollout status deployment/${env.RELEASE_NAME}-app --timeout=360s
                    curl -sf http://localhost:${env.NODE_PORT}/health/readiness
                    curl -sf http://localhost:${env.NODE_PORT}/health/liveness
                """
            }
        }
    }

    post {
        always { cleanWs() }
    }
}
