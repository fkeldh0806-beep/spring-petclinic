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
                    withAWS(credentials: AWS_CRED_ID, region: AWS_REGION) {
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}"
                    }

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
                        def imageUri = "${ECR_REPO_URL}:${IMAGE_TAG}"

                        def taskDefJson = sh( returnStdout: true, 
                            script: "aws ecs describe-task-definition --task-definition ${TASK_DEF_NAME}"
                        )
                        def taskDef = readJSON text: taskDefJson

                        
                        taskDef.taskDefinition.containerDefinitions.find { 
                            it.name == CONTAINER_NAME 
                        }.image = imageUri
                        
                        
                        taskDef.taskDefinition.remove('status')
                        taskDef.taskDefinition.remove('compatibilities')
                        
taskDef.taskDefinition.remove('requiresAttributes')
                        taskDef.taskDefinition.remove('revision')
                        taskDef.taskDefinition.remove('taskDefinitionArn')
                        
                        
                        def newTaskDef = sh(returnStdout: true, 
                            script: "aws ecs register-task-definition 
--cli-input-json '${taskDef.taskDefinition.toString().replace("'", 
"\\'")}'"
                        )
                        def newTaskDefArn = readJSON(text: 
newTaskDef).taskDefinition.taskDefinitionArn

                       
                        sh "aws ecs update-service --cluster 
${ECS_CLUSTER} --service ${ECS_SERVICE} --task-definition ${newTaskDefArn} 
--force-new-deployment"
                    }
                }
            }
        }
    }
}
