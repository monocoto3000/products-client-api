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
                expression { env.DEPLOY_ENV == 'production' }
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: SSH_CRED_ID, keyFileVariable: 'SSH_KEY'),
                    string(credentialsId: "db-host-production", variable: 'DB_HOST'),
                    string(credentialsId: "db-user-production", variable: 'DB_USER'),
                    string(credentialsId: "db-pass-production", variable: 'DB_PASS'),
                    string(credentialsId: "db-name-production", variable: 'DB_NAME')
                ]) {
                    sh 'chmod +x deploy-prod.sh'
                    sh './deploy-prod.sh'
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