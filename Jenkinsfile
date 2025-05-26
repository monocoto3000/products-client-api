pipeline {
    agent any

    environment {
        APP_NAME = ''
        REPO_URL = ''
        SSH_CRED_ID = 'ssh-key-ec2'
        EC2_USER = 'ubuntu'
        REMOTE_PATH = '/home/ubuntu/...'
    }

    stages {
        stage('Setup Environment') {
            steps {
                script {
                    def branch = env.GIT_BRANCH
                    if (!branch) {
                        env.DEPLOY_ENV = 'none'
                        echo "No se detectó rama, no se desplegará."
                        return
                    }
                    branch = branch.replaceAll('origin/', '')
                    echo "Rama detectada: ${branch}"

                    switch(branch) {
                        case 'master':
                            env.DEPLOY_ENV = 'production'
                            env.EC2_IP = ''
                            env.NODE_ENV = 'production'
                            break
                        case 'dev':
                            env.DEPLOY_ENV = 'development'
                            env.EC2_IP = ''
                            env.NODE_ENV = 'development'
                            break
                        case 'qa':
                            env.DEPLOY_ENV = 'qa'
                            env.EC2_IP = ''
                            env.NODE_ENV = 'qa'
                            break
                        default:
                            env.DEPLOY_ENV = 'none'
                            echo "No hay despliegue configurado para esta rama: ${branch}"
                    }
                }
            }
        }

        stage('Checkout') {
            when {
                expression { env.DEPLOY_ENV != 'none' }
            }
            steps {
                git branch: env.GIT_BRANCH.replaceAll('origin/', ''), url: "${REPO_URL}"
            }
        }

        stage('Build') {
            when {
                expression { env.DEPLOY_ENV != 'none' }
            }
            steps {
                sh 'rm -rf node_modules'
                sh 'npm ci'
                sh 'npm run build'
            }
        }

        stage('Deploy') {
            when {
                expression { env.DEPLOY_ENV != 'none' }
            }
            steps {
                script {
                    def envSuffix = env.DEPLOY_ENV
                    def sshKeyId = "ssh-key-ec2"
                    def dbHostId = "db-host-${envSuffix}"
                    def dbUserId = "db-user-${envSuffix}"
                    def dbPassId = "db-pass-${envSuffix}"
                    def dbNameId = "db-name-${envSuffix}"

                    withCredentials([
                        sshUserPrivateKey(credentialsId: SSH_CRED_ID, keyFileVariable: 'SSH_KEY'),
                        string(credentialsId: dbHostId, variable: 'DB_HOST'),
                        string(credentialsId: dbUserId, variable: 'DB_USER'),
                        string(credentialsId: dbPassId, variable: 'DB_PASS'),
                        string(credentialsId: dbNameId, variable: 'DB_NAME')
                    ]) {
                        sh 'chmod +x ./deploy.sh'    
                        def branchName = env.GIT_BRANCH.replaceAll('origin/', '')
                        sh """
                        SSH_KEY=\$SSH_KEY \
                        EC2_USER=\$EC2_USER \
                        EC2_IP=\$EC2_IP \
                        REMOTE_PATH=\$REMOTE_PATH \
                        REPO_URL=\$REPO_URL \
                        APP_NAME=\$APP_NAME \
                        NODE_ENV=\$NODE_ENV \
                        GIT_BRANCH=${branchName} \
                        DB_HOST=\$DB_HOST \
                        DB_USER=\$DB_USER \
                        DB_PASS=\$DB_PASS \
                        DB_NAME=\$DB_NAME \
                        ./deploy.sh
                        """
                    }
                    
                }
            }
        }
    }

    post {
        success {
            echo "Despliegue exitoso en ${env.DEPLOY_ENV}"
        }
        failure {
            echo "El despliegue en ${env.DEPLOY_ENV} ha fallado"
        }
    }
}