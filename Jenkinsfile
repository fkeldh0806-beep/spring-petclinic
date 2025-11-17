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
                git branch: 'main', 
                    credentialsId: 'github-ssh-key-for-checkout', 
                    url: 'git@github.com:fkeldh0806-beep/spring-petclinic.git' 
            }
        }
        
stage('2. Build & Push to ECR') {
            steps {
                script {
                    // 1. 필요한 도구 설치 (su -c로 root 권한 획득 후 설치)
                    sh 'su -c "apt-get update && apt-get install -y docker.io awscli"'
                    
                    // 2. AWS ECR 인증 및 Docker Login
                    withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
                        // docker login도 root 권한이 필요할 가능성이 높으므로 su -c 사용
                        sh "su -c 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}'"
                    }

                    // 3. Docker Build, Tag, Push
                    sh 'su -c "docker build -t petclinic-local ."'
                    sh "su -c 'docker tag petclinic-local:latest ${ECR_REPO_URL}:${IMAGE_TAG}'"
                    sh "su -c 'docker push ${ECR_REPO_URL}:${IMAGE_TAG}'"
                }
            }
        }
        
        stage('3. Deploy to ECS') {
            steps {
                withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
                    script {
                        def imageUri = "${ECR_REPO_URL}:${IMAGE_TAG}"

                        // Task Def 관련 AWS CLI 명령은 apt-get 설치 후에는 sudo/su 없이 작동해야 합니다.
                        def taskDefJson = sh(
                            returnStdout: true, 
                            script: "aws ecs describe-task-definition --task-definition ${TASK_DEF_NAME}"
                        )
                        def taskDef = readJSON text: taskDefJson

                        // ... (중간 JSON 처리 로직 유지)

                        def newTaskDef = sh(
                            returnStdout: true, 
                            script: "aws ecs register-task-definition --cli-input-json '${taskDef.taskDefinition.toString().replace("'", "\\'")}'"
                        )
                        def newTaskDefArn = readJSON(text: newTaskDef).taskDefinition.taskDefinitionArn

                        sh "aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${newTaskDefArn} --force-new-deployment"
                    }
                }
            }
        }
    }
}
