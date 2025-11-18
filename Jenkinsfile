pipeline {
    agent any
    
    // 🚨 1. 환경 변수 동적 설정 블록 추가
    // env.JOB_NAME을 기반으로 ECR, ECS 대상을 동적으로 설정합니다.
    stages {
        stage('0. Setup Environment') {
            steps {
                script {
                    // JOB_NAME 예: petclinic-cicd-back1 -> targetService: back1
                    def fullJobName = env.JOB_NAME
                    def targetService = fullJobName.tokenize('-').last() 
                    
                    // DB 연결 정보는 모든 서비스에 필요 없더라도 일단 정의
                    env.DB_HOST = 'petclinic-master.cfk48kygcx25.ap-northeast-2.rds.amazonaws.com'
                    env.DB_NAME = 'petclinic' 
                    env.DB_USER = 'postgres' 
                    env.DB_PASSWORD = 'zx1357zx99' 
                    
                    // 각 Job에서 Jenkins 설정 > 환경 변수(Environment variables)에
                    // ECR_REPO_URL, ECS_SERVICE, TASK_DEF_NAME을 덮어쓰기 설정해야 합니다.
                    // 만약 Jenkins Job 설정에서 덮어쓰기를 하지 않았다면 여기서 기본값 설정:
                    
                    if (targetService == 'back1') {
                        env.ECR_REPO_NAME = 'back1' // 리포지토리 이름만 사용
                        env.TASK_DEF_NAME = 'back1-task'
                        env.ECS_SERVICE = 'back1-service'
                        env.CONTAINER_NAME = 'back1'
                    } else if (targetService == 'back2') {
                        env.ECR_REPO_NAME = 'back2' // 리포지토리 이름만 사용
                        env.TASK_DEF_NAME = 'back2-task'
                        env.ECS_SERVICE = 'back2-service'
                        env.CONTAINER_NAME = 'back2'
                    } else if (targetService == 'front') {
                        env.ECR_REPO_NAME = 'front' // 리포지토리 이름만 사용
                        env.TASK_DEF_NAME = 'front-task'
                        env.ECS_SERVICE = 'front-service'
                        env.CONTAINER_NAME = 'front'
                    }
                    
                    // 모든 Job에 공통 적용되는 환경 변수
                    env.AWS_CRED_ID = 'aws-iam-credentials'          
                    env.AWS_REGION = 'ap-northeast-2'
                    env.ECS_CLUSTER = 'petclinic-cluster'
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}"
                    env.ECR_REPO_URL = "556152726180.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO_NAME}"

                    echo "--- Deployment target: ${targetService} ---"
                    echo "ECR_REPO_URL: ${env.ECR_REPO_URL}"
                    echo "ECS_SERVICE: ${env.ECS_SERVICE}"
                }
            }
        }
        
        stage('1. Checkout Code') {
            steps {
                // ... (생략)
                sh 'curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o jq'
                sh 'chmod +x jq'
                git branch: 'main', 
                    credentialsId: 'github-ssh-key-for-checkout', 
                    url: 'git@github.com:fkeldh0806-beep/spring-petclinic.git' 
            }
        }
        
        stage('2. Build & Push to ECR') {
            steps {
                script {
                    // 2. AWS ECR 인증 및 Docker Login (su -c 제거)
                    withAWS(credentials: env.AWS_CRED_ID, region: env.AWS_REGION) {
                        sh "aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_REPO_URL}"
                    }

                    // 3. Docker Build, Tag, Push
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
                        def jqCommand = ""
                        
                        if (targetService == 'back1' || targetService == 'back2') {
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
                            // front는 DB 연결 없이 이미지 업데이트만
                            jqCommand = ".containerDefinitions[0].image=\"${imageUri}\""
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

                        // JSON 문자열을 그대로 사용하여 새로운 태스크 정의 등록
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