pipeline {
 agent any
    
    environment {
        AWS_CRED_ID    = 'aws-iam-credentials'          
        AWS_REGION     = 'ap-northeast-2'
        
        ECR_REPO_URL   = '556152726180.dkr.ecr.ap-northeast-2.amazonaws.com/back1'
        
        ECS_CLUSTER    = 'petclinic-cluster'           
        ECS_SERVICE    = 'back1-service'
        TASK_DEF_NAME  = 'back1-task'
        CONTAINER_NAME = 'back1'
        
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('1. Checkout Code') {
            steps {
                sh 'apt-get update && apt-get install -y jq'
                git branch: 'main', 
                    credentialsId: 'github-ssh-key-for-checkout', 
                    url: 'git@github.com:fkeldh0806-beep/spring-petclinic.git' 
            }
        }
        
stage('2. Build & Push to ECR') {
            steps {
                script {
                    // 1. apt-get 설치 명령어는 삭제하거나 주석 처리
                    // sh 'su -c "apt-get update && apt-get install -y docker.io awscli"' 
                    
                    // 2. AWS ECR 인증 및 Docker Login (su -c 제거)
                    withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
                        // Docker와 AWS CLI가 설치되어 있어야 실행됩니다.
                        // 이전에 실패했던 환경(docker: not found)으로 돌아갈 수 있습니다.
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}"
                    }

                    // 3. Docker Build, Tag, Push
                    sh "docker build -t petclinic-local ."
                    sh "docker tag petclinic-local:latest ${ECR_REPO_URL}:${IMAGE_TAG}"
                    sh "docker push ${ECR_REPO_URL}:${IMAGE_TAG}"
                }
            }
        }
        
      stage('3. Deploy to ECS') {
    steps {
        withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
            script {
                // 새로 빌드된 이미지 URI (예: 556152726180.dkr.ecr.ap-northeast-2.amazonaws.com/back1:38)
                def imageUri = "${ECR_REPO_URL}:${IMAGE_TAG}"

                def taskDefJson = sh(
                    returnStdout: true, 
                    script: "aws ecs describe-task-definition --task-definition ${TASK_DEF_NAME}"
                )
                
                // 🚨 기존 코드를 아래 코드로 대체하여 JSON을 정리합니다.
                def newTaskDefJson = sh(
                    returnStdout: true,
                    script: """
                        echo '${taskDefJson}' | jq -c '.taskDefinition | 
                        del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy) | 
                        .containerDefinitions[0].image=\"${imageUri}\"
                        '
                    """
                ).trim()

                // JSON 문자열을 그대로 사용하여 새로운 태스크 정의 등록
                def newTaskDef = sh(
                    returnStdout: true, 
                    script: "aws ecs register-task-definition --cli-input-json '${newTaskDefJson}'"
                )
                def newTaskDefArn = readJSON(text: newTaskDef).taskDefinition.taskDefinitionArn

                sh "aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${newTaskDefArn} --force-new-deployment"
            }
        }
    }
}
    }
}
