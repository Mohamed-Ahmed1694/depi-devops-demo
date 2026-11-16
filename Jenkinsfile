// OPTIONAL lesson: the same pipeline in Jenkins. Install Jenkins with: make jenkins
// The main CI/CD is GitHub Actions (.github/workflows/ci-cd.yml). Jenkins runs only when you click Build Now.
// Build Now -> test -> build Docker image -> load into K3s -> deploy -> smoke test
pipeline {
    agent any

    // No automatic trigger on purpose: GitHub Actions deploys on every push.
    // In Jenkins you click "Build Now", so the two pipelines never deploy at the same time.

    environment {
        IMAGE      = 'depi-demo-app'
        TAG        = "${env.BUILD_NUMBER}"
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Unit Tests') {
            steps {
                sh '''
                  docker run --rm -v "$WORKSPACE/app":/app -w /app python:3.12-slim \
                    sh -c "pip install -q -r requirements.txt && pytest -q"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build --build-arg APP_VERSION=$TAG -t $IMAGE:$TAG -t $IMAGE:latest app/'
            }
        }

        stage('Load Image into K3s') {
            steps {
                // No registry needed: copy the image straight into K3s' containerd
                sh 'docker save $IMAGE:$TAG | sudo /usr/local/bin/k3s ctr images import -'
            }
        }

        stage('Deploy to K3s') {
            steps {
                sh '''
                  sed "s|$IMAGE:latest|$IMAGE:$TAG|" k8s/app/app.yaml | kubectl apply -f -
                  kubectl -n demo rollout status deployment/demo-app --timeout=120s
                '''
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                  sleep 3
                  curl -fs http://localhost:30080/health
                  curl -fs http://localhost:30080/api | grep -q "\"version\":\"$TAG\""
                '''
            }
        }
    }

    post {
        success { echo "Deployed version ${env.TAG} -> http://<SERVER_IP>:30080" }
        failure { echo 'Pipeline failed - check the stage logs above.' }
        always  { sh 'docker image prune -f || true' }
    }
}
