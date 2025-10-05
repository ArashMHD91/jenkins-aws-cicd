pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = '503561416397'
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/jenkins-cicd-app"
        APP_NAME = 'jenkins-cicd-app'
        DEPLOYMENT_GROUP = 'production'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "✓ Code checked out from GitHub"
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    docker.image('python:3.11-slim').inside {
                        sh '''
                            cd app
                            pip install -r requirements.txt
                            pytest test_app.py -v
                        '''
                    }
                }
                echo "✓ Tests passed successfully"
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    dockerImage = docker.build("${ECR_REPO}:${IMAGE_TAG}")
                    docker.build("${ECR_REPO}:latest")
                }
                echo "✓ Docker image built successfully"
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REPO}
                            
                            docker push ${ECR_REPO}:${IMAGE_TAG}
                            docker push ${ECR_REPO}:latest
                        """
                    }
                }
                echo "✓ Docker image pushed to ECR"
            }
        }
        
        stage('Deploy with CodeDeploy') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh """
                            aws deploy create-deployment \
                              --application-name ${APP_NAME} \
                              --deployment-group-name ${DEPLOYMENT_GROUP} \
                              --deployment-config-name CodeDeployDefault.AllAtOnce \
                              --description "Deployment from Jenkins Build ${BUILD_NUMBER}" \
                              --s3-location bucket=aws-codedeploy-${AWS_REGION},bundleType=zip,key=app-${BUILD_NUMBER}.zip || \
                            aws deploy create-deployment \
                              --application-name ${APP_NAME} \
                              --deployment-group-name ${DEPLOYMENT_GROUP} \
                              --deployment-config-name CodeDeployDefault.AllAtOnce \
                              --description "Deployment from Jenkins Build ${BUILD_NUMBER}" \
                              --github-location repository=\${GIT_URL#https://github.com/},commitId=\${GIT_COMMIT}
                        """
                    }
                }
                echo "✓ Deployment initiated via CodeDeploy"
            }
        }
    }
    
    post {
        success {
            echo '=========================================='
            echo '✓ Pipeline completed successfully!'
            echo '=========================================='
        }
        failure {
            echo '=========================================='
            echo '✗ Pipeline failed!'
            echo '=========================================='
        }
        always {
            cleanWs()
        }
    }
}