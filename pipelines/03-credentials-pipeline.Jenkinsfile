// Lab 3: Credentials binding.
// Prerequisite: in Manage Jenkins > Credentials > (global), add a "Secret text"
// credential with ID 'my-api-token' (use a dummy value for the lab).
pipeline {
  agent any

  environment {
    // Binds the credential to an environment variable. Jenkins masks it in logs.
    MY_SECRET_TOKEN = credentials('my-api-token')
  }

  stages {
    stage('Authenticate and Deploy') {
      steps {
        echo 'Accessing remote API securely...'
        // Single quotes: the SHELL reads $MY_SECRET_TOKEN, Groovy never sees the value.
        // The console shows **** instead of the real secret.
        sh '''
          echo "Attempting login with token: $MY_SECRET_TOKEN"
        '''
      }
    }
  }
}
