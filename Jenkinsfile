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
                    // **sudo**를 사용하여 루트 권한으로 실행
                    sh "sudo apt-get update && sudo apt-get install -y docker.io awscli" 
                    
                    // ECR 로그인부터 모든 쉘 명령에 sudo를 붙여야 합니다.
                    withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
                        sh "sudo aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${ECR_REPO_URL}"
                    }

                    sh "sudo docker build -t petclinic-local ."
                    sh "sudo docker tag petclinic-local:latest ${ECR_REPO_URL}:${IMAGE_TAG}"

                    sh "sudo docker push ${ECR_REPO_URL}:${IMAGE_TAG}"
                }
            }
        }
        
        stage('3. Deploy to ECS') {
            steps {
                withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
                    script {
                        def imageUri = "${ECR_REPO_URL}:${IMAGE_TAG}"

                        // Task Def 관련 AWS CLI 명령에도 모두 sudo를 붙여야 합니다.
                        def taskDefJson = sh(
                            returnStdout: true, 
                            script: "sudo aws ecs describe-task-definition --task-definition ${TASK_DEF_NAME}"
                        )
                        def taskDef = readJSON text: taskDefJson

                        // ... (중간 JSON 처리 로직은 그대로)

                        def newTaskDef = sh(
                            returnStdout: true, 
                            // JSON 문자열 처리 때문에 이 줄은 길지만, sudo를 앞에 붙입니다.
                            script: "sudo aws ecs register-task-definition --cli-input-json '${taskDef.taskDefinition.toString().replace("'", "\\'")}'"
                        )
                        def newTaskDefArn = readJSON(text: newTaskDef).taskDefinition.taskDefinitionArn

                        sh "sudo aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${newTaskDefArn} --force-new-deployment"
                    }
                }
            }
        }
    }
}
