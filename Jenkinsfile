pipeline {
    agent any
    
    // 🚨 1. AWS 자격 증명 및 DB 정보는 한 곳에서 정의합니다.
    environment {
        AWS_CRED_ID    = 'aws-iam-credentials'          
        AWS_REGION     = 'ap-northeast-2'
        ECS_CLUSTER    = 'petclinic-cluster'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        
        // DB 연결 정보 (백엔드 서비스에서 사용)
        DB_HOST = 'petclinic-master.cfk48kygcx25.ap-northeast-2.rds.amazonaws.com' // 🚨 실제 Master 엔드포인트로 변경하세요
        DB_NAME = 'petclinic' 
        DB_USER = 'postgres' 
        DB_PASSWORD = 'zx1357zx99'
    }
    
    stages {
        stage('0. Setup Environment') {
            steps {
                script {
                    // Job 이름을 분석하여 targetService (back1, back2, front) 식별
                    def fullJobName = env.JOB_NAME
                    env.targetService = fullJobName.tokenize('-').last() 
                    
                    // 각 서비스에 맞는 ECR/ECS 변수를 env에 설정 (전역 변수로 승격)
                    env.ECR_REPO_NAME = env.targetService
                    env.TASK_DEF_NAME = "${env.targetService}-task"
                    env.ECS_SERVICE = "${env.targetService}-service"
                    env.CONTAINER_NAME = env.targetService
                    env.ECR_REPO_URL = "556152726180.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO_NAME}"

                    echo "--- Deployment target: ${env.targetService} ---"
                    echo "ECR_REPO_URL: ${env.ECR_REPO_URL}"
                    echo "ECS_SERVICE: ${env.ECS_SERVICE}"
                }
            }
        }
        
        stage('1. Checkout Code') {
            steps {
                sh 'curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o jq'
                sh 'chmod +x jq'
                // 코드 checkout은 모든 Job에서 동일합니다.
                git branch: 'main', 
                    credentialsId: 'github-ssh-key-for-checkout', 
                    url: 'git@github.com:fkeldh0806-beep/spring-petclinic.git' 
            }
        }
        
        stage('2. Build & Push to ECR') {
            steps {
                script {
                    withAWS(credentials: env.AWS_CRED_ID, region: env.AWS_REGION) {
                        sh "aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_REPO_URL}"
                    }

                    sh "docker build -t petclinic-local ."
                    sh "docker tag petclinic-local:latest ${env.ECR_REPO_URL}:${env.IMAGE_TAG}"
                    sh "docker push ${env.ECR_REPO_URL}:${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('3. Deploy to ECS') {
            steps {
                withAWS(credentials: env.AWS_CRED_ID, region: env.AWS_REGION) {
                    script {
                        def imageUri = "${env.ECR_REPO_URL}:${env.IMAGE_TAG}"

                        def taskDefJson = sh(
                            returnStdout: true, 
                            script: "aws ecs describe-task-definition --task-definition ${env.TASK_DEF_NAME}"
                        )
                        
                        // 🚨 2. DB 연결 로직 조건부 실행 (front는 제외)
                        def jqCommand = ".containerDefinitions[0].image=\"${imageUri}\""
                        
                        if (env.targetService == 'back1' || env.targetService == 'back2') {
                             // back1, back2는 DB 연결 환경 변수 주입
                             jqCommand = """
                                .containerDefinitions[0].image=\"${imageUri}\" |
                                .containerDefinitions[0].environment = [
                                    { "name": "SPRING_PROFILES_ACTIVE", "value": "postgres" },
                                    { "name": "SPRING_DATASOURCE_URL", "value": "jdbc:postgresql://${env.DB_HOST}:5432/${env.DB_NAME}" }, 
                                    { "name": "SPRING_DATASOURCE_USERNAME", "value": "${env.DB_USER}" },
                                    { "name": "SPRING_DATASOURCE_PASSWORD", "value": "${env.DB_PASSWORD}" }
                                ]
                                """
                        } else {
                            // front는 DB 연결 없이 이미지 업데이트만 하므로 jqCommand는 기본값 유지
                        }
                        
                        def newTaskDefJson = sh(
                            returnStdout: true,
                            script: """
                                echo '${taskDefJson}' | ./jq '.taskDefinition | 
                                del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy) | 
                                ${jqCommand}
                                '
                            """
                        ).trim()

                        def newTaskDef = sh(
                            returnStdout: true, 
                            script: "aws ecs register-task-definition --cli-input-json '${newTaskDefJson}'"
                        )
                        def newTaskDefArn = readJSON(text: newTaskDef).taskDefinition.taskDefinitionArn

                        sh "aws ecs update-service --cluster ${env.ECS_CLUSTER} --service ${env.ECS_SERVICE} --task-definition ${newTaskDefArn} --force-new-deployment"
                    }
                }
            }
        }
    }
}