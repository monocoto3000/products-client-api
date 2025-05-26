pipeline {
    agent any

    environment {
        APP_NAME = 'products-client-api'
        REPO_URL = 'https://github.com/monocoto3000/products-client-api.git'
        SSH_CRED_ID = 'ssh-key-ec2'
        EC2_USER = 'ubuntu'
        REMOTE_PATH = '/home/ubuntu/products-client-api'
    }

    stages {
        stage('Detect Branch & Set Environment') {
            steps {
                script {
                    def branch = env.GIT_BRANCH ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    branch = branch.replaceAll('origin/', '')
                    echo "Rama detectada: ${branch}"

                    switch (branch) {
                        case 'main':
                            env.DEPLOY_ENV = 'production'
                            env.EC2_IP = '44.205.201.108'
                            env.NODE_ENV = 'production'
                            break
                        case 'dev':
                            env.DEPLOY_ENV = 'development'
                            env.EC2_IP = '107.22.77.233'
                            env.NODE_ENV = 'development'
                            break
                        case 'qa':
                            env.DEPLOY_ENV = 'qa'
                            env.EC2_IP = '3.227.65.63'
                            env.NODE_ENV = 'qa'
                            break
                        default:
                            error("No hay entorno configurado para esta rama: ${branch}")
                    }

                    env.BRANCH_NAME = branch
                }
            }
        }

        stage('Checkout') {
            steps {
                git branch: env.BRANCH_NAME, url: "${REPO_URL}"
            }
        }

        stage('Install & Build') {
            steps {
                sh 'rm -rf node_modules'
                sh 'npm ci'
                sh 'npm run build'
            }
        }

        stage('Deploy') {
            steps {
                script {
                    def envSuffix = env.DEPLOY_ENV
                    withCredentials([
                        sshUserPrivateKey(credentialsId: SSH_CRED_ID, keyFileVariable: 'SSH_KEY'),
                        string(credentialsId: "db-host-${envSuffix}", variable: 'DB_HOST'),
                        string(credentialsId: "db-user-${envSuffix}", variable: 'DB_USER'),
                        string(credentialsId: "db-pass-${envSuffix}", variable: 'DB_PASS'),
                        string(credentialsId: "db-name-${envSuffix}", variable: 'DB_NAME')
                    ]) {
                        sh 'chmod +x ./deploy.sh'
                        sh """
                        SSH_KEY=$SSH_KEY \
                        EC2_USER=$EC2_USER \
                        EC2_IP=$EC2_IP \
                        REMOTE_PATH=$REMOTE_PATH \
                        REPO_URL=$REPO_URL \
                        APP_NAME=$APP_NAME \
                        NODE_ENV=$NODE_ENV \
                        GIT_BRANCH=$BRANCH_NAME \
                        DB_HOST=$DB_HOST \
                        DB_USER=$DB_USER \
                        DB_PASS=$DB_PASS \
                        DB_NAME=$DB_NAME \
                        ./deploy.sh
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Despliegue exitoso en '${env.DEPLOY_ENV}'."
        }
        failure {
            echo "❌ El despliegue en '${env.DEPLOY_ENV}' ha fallado."
        }
    }
}
