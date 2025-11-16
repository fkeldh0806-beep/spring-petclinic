pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-northeast-2'
        ECR_REPO_FRONT = '556152726180.dkr.ecr.ap-northeast-2.amazonaws.com/front'
        ECR_REPO_BACK1 = '556152726180.dkr.ecr.ap-northeast-2.amazonaws.com/back1'
        ECR_REPO_BACK2 = '556152726180.dkr.ecr.ap-northeast-2.amazonaws.com/back2'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        AWS_CREDENTIALS = 'aws-cred'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/fkeldh0806-beep/spring-petclinic.git'
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    sh "docker build -t ${ECR_REPO_FRONT}:${IMAGE_TAG} ."
                    sh "docker build -t ${ECR_REPO_BACK1}:${IMAGE_TAG} ."
                    sh "docker build -t ${ECR_REPO_BACK2}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_DEFAULT_REGION}") {
                    sh "aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_REPO_FRONT}"
                    sh "docker push ${ECR_REPO_FRONT}:${IMAGE_TAG}"
                    sh "docker push ${ECR_REPO_BACK1}:${IMAGE_TAG}"
                    sh "docker push ${ECR_REPO_BACK2}:${IMAGE_TAG}"
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_DEFAULT_REGION}") {
                    sh "aws ecs update-service --cluster petclinic-cluster --service front-service --force-new-deployment"
                    sh "aws ecs update-service --cluster petclinic-cluster --service back1-service --force-new-deployment"
                    sh "aws ecs update-service --cluster petclinic-cluster --service back2-service --force-new-deployment"
                }
            }
        }
    }
}
