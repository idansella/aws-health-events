pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout(scm)
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'pip3 install pyyaml boto3'
            }
        }

        stage('Run for All Accounts') {
            steps {
                script {
                    def mapping = readYaml file: 'account-mapping.yaml'
                    parallel mapping.accounts.collectEntries { acc ->
                        ["${acc.account_id}" : {
                            withAWS(role: 'Jenkins_role', accountId: acc.account_id) {
                                sh """
                                    export SLACK_WEBHOOK_URL=${acc.slack_webhook}
                                    export SLACK_CHANNEL=${acc.slack_channel}
                                    python3 aws_health_events.py
                                """
                            }
                        }]
                    }
                }
            }
        }
    }
}
