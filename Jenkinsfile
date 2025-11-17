pipeline {
    agent any
    
    // ⚠️ 환경 변수: 아래 'YOUR_...' 부분은 반드시 실제 값으로 변경하세요!
    environment {
        // Task 3에서 재등록한 AWS Credential ID (ECR/ECS 권한)
        AWS_CRED_ID    = 'aws-iam-credentials'          
        AWS_REGION     = 'ap-northeast-2'
        
        // ECR 리포지토리 URL (AWS 계정 ID 포함)
        ECR_REPO_URL   = 
'556152726180.dkr.ecr.ap-northeast-2.amazonaws.com/back1'
        
        // ECS 클러스터 및 서비스 정보 (Task 5에서 생성)
        ECS_CLUSTER    = 'petclinic-cluster'           
        ECS_SERVICE    = 'back1-service'
        TASK_DEF_NAME  = 'back1-task’
        CONTAINER_NAME = 'back1'   // Task Definition에 정의된 컨테이너 
이름
        
        // Jenkins 빌드 번호를 이미지 태그로 사용
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('1. Checkout Code') {
            steps {
                // ✅ Git SSH 키 인증 (이전 단계에서 새로 등록한 ID 사용)
                git branch: 'main', 
                    credentialsId: 'github-ssh-key-for-checkout', // 새로 
등록한 GitHub Credential ID
                    url: 
'git@github.com:fkeldh0806-beep/spring-petclinic.git' 
            }
        }
        
        stage('2. Build & Push to ECR') {
            steps {
                script {
                    // 1. AWS ECR 인증 및 Docker Login
                    withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) 
{
                        sh "aws ecr get-login-password --region 
${AWS_REGION} | docker login --username AWS --password-stdin 
${ECR_REPO_URL}"
                    }

                    // 2. Docker 이미지 빌드 및 태깅 (PetClinic의 
Dockerfile을 사용)
                    sh "docker build -t petclinic-local ."
                    sh "docker tag petclinic-local:latest 
${ECR_REPO_URL}:${IMAGE_TAG}"

                    // 3. ECR에 이미지 푸시
                    sh "docker push ${ECR_REPO_URL}:${IMAGE_TAG}"
                }
            }
        }

        stage('3. Deploy to ECS') {
            steps {
                withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
                    script {
                        def imageUri = "${ECR_REPO_URL}:${IMAGE_TAG}"

                        // 1. Task Definition JSON 가져오기
                        def taskDefJson = sh(
                            returnStdout: true, 
                            script: "aws ecs describe-task-definition 
--task-definition ${TASK_DEF_NAME}"
                        )
                        def taskDef = readJSON text: taskDefJson

                        // 2. Container Image URI 업데이트
                        taskDef.taskDefinition.containerDefinitions.find { 
                            it.name == CONTAINER_NAME 
                        }.image = imageUri
                        
                        // 3. Task Definition 재등록을 위한 불필요한 필드 
제거
                        taskDef.taskDefinition.remove('status')
                        taskDef.taskDefinition.remove('compatibilities')
                        
taskDef.taskDefinition.remove('requiresAttributes')
                        taskDef.taskDefinition.remove('revision')
                        taskDef.taskDefinition.remove('taskDefinitionArn')
                        
                        // 4. 새로운 Task Definition 등록
                        def newTaskDef = sh(
                            returnStdout: true, 
                            script: "aws ecs register-task-definition 
--cli-input-json '${taskDef.taskDefinition.toString().replace("'", 
"\\'")}'"
                        )
                        def newTaskDefArn = readJSON(text: 
newTaskDef).taskDefinition.taskDefinitionArn

                        // 5. ECS Service 업데이트 (강제 새 배포 시작)
                        sh "aws ecs update-service --cluster 
${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${newTaskDefArn} 
--force-new-deployment"
                    }
                }
            }
        }
    }
}


