pipeline {
    agent any
    
    // 🚨 1. AWS 자격 증명 및 DB 정보는 한 곳에서 정의합니다.
    environment {
        AWS_CRED_ID    = 'aws-iam-credentials'          
        AWS_REGION     = 'ap-northeast-2'
        ECS_CLUSTER    = 'petclinic-cluster'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"

        // Blue/Green Target Group 정의
        GREEN_TG_NAME = "${env.targetService}-tg-green"
        BLUE_TG_NAME = "${env.targetService}-tg" // 기존 TG는 Blue로 간주
        
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

                        // 🚨 3. 무중단 배포 (Blue/Green) 로직 시작

                        // 3-1. 신규 Task Definition을 Green Target Group에 연결하여 배포
                        sh "aws ecs update-service --cluster ${env.ECS_CLUSTER} --service ${env.ECS_SERVICE} --task-definition ${newTaskDefArn} --force-new-deployment --target-group ${env.GREEN_TG_NAME}"

                        echo "INFO: Waiting for new tasks to become healthy in ${env.GREEN_TG_NAME}..."
                        // 3-2. 신규 Task가 Healthy 상태가 될 때까지 기다림 (약 300초/5분)
                        sh "aws ecs wait services-stable --cluster ${env.ECS_CLUSTER} --services ${env.ECS_SERVICE}"

                        // 3-3. ALB 규칙 전환 (트래픽을 Green으로 이동)
                        // ALB 리스너 ARN과 규칙 ARN을 찾아야 합니다. (이는 AWS 콘솔에서 수동으로 찾아야 함)
                        // 편의를 위해 일단 임시 변수 처리하겠습니다. 실제 ARN으로 교체 필요.
                        def ALB_LISTENER_ARN = 'arn:aws:elasticloadbalancing:ap-northeast-2:556152726180:loadbalancer/app/petclinic-alb/e465b04aacd23bb7' // 🚨 실제 ALB 리스너 ARN으로 교체
                        def RULE_ARN_VETS = 'arn:aws:elasticloadbalancing:ap-northeast-2:556152726180:listener-rule/app/petclinic-alb/e465b04aacd23bb7/655379ee86faf010/cb5f7e43d4da34dc' // 🚨 back1 (Vets) 규칙 ARN으로 교체
                        def RULE_ARN_OWNERS = 'arn:aws:elasticloadbalancing:ap-northeast-2:556152726180:listener-rule/app/petclinic-alb/e465b04aacd23bb7/655379ee86faf010/088710738448432a' // 🚨 back2 (Owners) 규칙 ARN으로 교체
                        
                        // 3-4. (front) Default 규칙 전환: front는 Default 규칙을 사용하며, Default 규칙의 Target Group을 Green으로 교체
                        if (env.targetService == 'front') {
                            sh """
                                aws elbv2 modify-listener --listener-arn ${ALB_LISTENER_ARN} --default-actions '[{"Type": "forward", "TargetGroupArn": "${env.GREEN_TG_NAME}"}]'
                                echo "INFO: Default Listener Rule (front-service) switched to ${env.GREEN_TG_NAME}"
                            """
                        }
                        
                        // 3-5. (back1/back2) Path 규칙 전환: Path 규칙의 Target Group을 Green으로 교체
                        if (env.targetService == 'back1') {
                            sh """
                                aws elbv2 modify-listener-rule --rule-arn ${RULE_ARN_VETS} --actions '[{"Type": "forward", "TargetGroupArn": "${env.GREEN_TG_NAME}"}]'
                                echo "INFO: Vets Path Rule (back1-service) switched to ${env.GREEN_TG_NAME}"
                            """
                        } else if (env.targetService == 'back2') {
                            sh """
                                aws elbv2 modify-listener-rule --rule-arn ${RULE_ARN_OWNERS} --actions '[{"Type": "forward", "TargetGroupArn": "${env.GREEN_TG_NAME}"}]'
                                echo "INFO: Owners Path Rule (back2-service) switched to ${env.GREEN_TG_NAME}"
                            """
                        }

                        // 3-6. 기존 Blue Target Group의 Task 제거 (선택적)
                        echo "INFO: Cleaning up old tasks in Blue TG (${env.BLUE_TG_NAME})"
                        // (ECS Task를 Blue TG에서 제거하는 AWS CLI 명령 추가 가능)
                        
                        echo "SUCCESS: Deployment completed via Blue/Green swap."
                    }
                }
            }
        }
    }
}