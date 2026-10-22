// Lab 2: Declarative Pipeline with stages, environment variables,
// post actions, and a fingerprinted artifact.
pipeline {
  agent any

  environment {
    APP_NAME  = 'Sample Portal'
    BUILD_ENV = 'Testing'
  }

  stages {
    stage('Environment Check') {
      steps {
        echo "Building application: ${env.APP_NAME}"
        echo "Deploying to environment: ${env.BUILD_ENV}"
        echo "Current Build Number: ${env.BUILD_NUMBER}"
      }
    }

    stage('Build Phase') {
      steps {
        echo 'Compiling code into a deployment package...'
        sh 'echo "Compiled binary for ${APP_NAME}" > application.bin'
      }
    }

    stage('Test Phase') {
      steps {
        echo 'Running automated unit tests...'
        sh 'test -f application.bin'   // fails the stage if the file is missing
        echo 'Tests Passed!'
      }
    }

    stage('Archive Artifacts') {
      steps {
        archiveArtifacts artifacts: 'application.bin', fingerprint: true
      }
    }
  }

  post {
    always  { echo 'Pipeline execution finished.' }
    success { echo 'Pipeline passed all stages!' }
    failure { echo 'Pipeline execution failed!' }
  }
}
