pipeline {
    agent {
        label 'dynamic-agent'
    }

    parameters {
        choice(
            name: 'INFRA_ACTION',
            choices: [
                'Update existing infrastructure',
                'Destroy and rebuild infrastructure'
            ],
            description: 'Update existing infrastructure or destroy and recreate it.'
        )
    }

    environment {
        TF_IN_AUTOMATION = 'true'

        AWS_ACCOUNT_ID     = '560904638794'
        AWS_DEFAULT_REGION = 'eu-north-1'
        ECR_REPOSITORY     = 'springboot-app'
        IMAGE_TAG          = 'latest'

        SSH_USER = 'ubuntu'

        K8S_NAMESPACE  = 'springboot'
        K8S_DEPLOYMENT = 'springboot-app'
        K8S_SERVICE    = 'springboot-service'

        HOST_PORT    = '8080'
        SERVICE_PORT = '8080'
        NODE_PORT    = '30080'

        REMOTE_K8S_DIR = '/home/ubuntu/kubernetes'

        INFRA_EXISTS = 'false'
    }

    stages {

        stage('Checkout Terraform Project') {
            steps {
                echo 'Checking out Terraform CD project...'

                git branch: 'main',
                    url: 'https://github.com/rutujaf96/terraform-vpc-project.git'
            }
        }

        stage('Terraform Init') {
            steps {
                echo 'Initializing Terraform and loading remote state...'

                sh '''
                    set -e
                    terraform init -reconfigure
                '''
            }
        }

        stage('Check Existing Infrastructure') {
            steps {
                script {
                    def stateResources = sh(
                        script: '''
                            terraform state list 2>/dev/null || true
                        ''',
                        returnStdout: true
                    ).trim()

                    if (stateResources) {
                        env.INFRA_EXISTS = 'true'

                        echo 'Existing Terraform-managed infrastructure found.'
                        echo 'Resources in Terraform state:'
                        echo stateResources
                    } else {
                        env.INFRA_EXISTS = 'false'

                        echo 'No Terraform-managed infrastructure found.'
                        echo 'New infrastructure will be created.'
                    }

                    echo "Selected action: ${params.INFRA_ACTION}"
                    echo "Infrastructure exists: ${env.INFRA_EXISTS}"
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                echo 'Validating Terraform configuration...'

                sh '''
                    set -e
                    terraform validate
                '''
            }
        }

        stage('Destroy Existing Infrastructure') {
            when {
                allOf {
                    expression {
                        params.INFRA_ACTION == 'Destroy and rebuild infrastructure'
                    }

                    expression {
                        env.INFRA_EXISTS == 'true'
                    }
                }
            }

            steps {
                echo 'Destroy and rebuild option selected.'
                echo 'Destroying existing Terraform infrastructure...'

                sh '''
                    set -e

                    rm -f tfdestroyplan

                    terraform plan \
                        -destroy \
                        -out=tfdestroyplan

                    terraform apply \
                        -auto-approve \
                        tfdestroyplan
                '''

                script {
                    env.INFRA_EXISTS = 'false'
                }

                echo 'Existing infrastructure destroyed successfully.'
            }
        }

        stage('Infrastructure Action Information') {
            steps {
                script {
                    if (params.INFRA_ACTION == 'Update existing infrastructure') {
                        if (env.INFRA_EXISTS == 'true') {
                            echo 'Existing infrastructure will be updated.'
                            echo 'Destroy stage is skipped.'
                        } else {
                            echo 'Infrastructure does not exist.'
                            echo 'New infrastructure will be created.'
                        }
                    } else {
                        if (env.INFRA_EXISTS == 'false') {
                            echo 'Destroy is completed or no infrastructure existed.'
                            echo 'New infrastructure will now be created.'
                        }
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                echo 'Creating Terraform execution plan...'

                sh '''
                    set -e

                    rm -f tfplan

                    terraform plan \
                        -out=tfplan
                '''
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    if (
                        params.INFRA_ACTION == 'Update existing infrastructure' &&
                        env.INFRA_EXISTS == 'true'
                    ) {
                        echo 'Applying updates to existing infrastructure.'
                    } else {
                        echo 'Creating new infrastructure.'
                    }
                }

                sh '''
                    set -e

                    terraform apply \
                        -auto-approve \
                        tfplan
                '''
            }
        }

        stage('Get Terraform Outputs') {
            steps {
                script {
                    env.EC2_IP = sh(
                        script: 'terraform output -raw ec2_public_ip',
                        returnStdout: true
                    ).trim()

                    env.LAMBDA_NAME = sh(
                        script: 'terraform output -raw lambda_function_name',
                        returnStdout: true
                    ).trim()

                    if (!env.EC2_IP) {
                        error('Terraform EC2 public IP output is empty.')
                    }

                    if (!env.LAMBDA_NAME) {
                        error('Terraform Lambda function name output is empty.')
                    }

                    echo "EC2 Public IP: ${env.EC2_IP}"
                    echo "Lambda Function: ${env.LAMBDA_NAME}"
                }
            }
        }

        stage('Wait For SSH') {
            steps {
                echo 'Waiting for EC2 SSH service...'

                sh '''
                    set -e

                    for i in $(seq 1 30)
                    do
                        if nc -z "${EC2_IP}" 22; then
                            echo "SSH is available on ${EC2_IP}"
                            exit 0
                        fi

                        echo "Attempt ${i}/30: SSH is not ready."
                        sleep 10
                    done

                    echo "ERROR: SSH did not become available."
                    exit 1
                '''
            }
        }

        stage('Create Ansible Inventory') {
            steps {
                echo 'Creating Ansible inventory...'

                sh '''
                    set -e

                    mkdir -p ansible

                    cat > ansible/hosts <<EOF
[web]
${EC2_IP} ansible_user=${SSH_USER}
EOF

                    echo "Generated Ansible inventory:"
                    cat ansible/hosts
                '''
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                echo 'Installing Java, Docker, AWS CLI, kubectl and Minikube...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        export ANSIBLE_CONFIG="${WORKSPACE}/ansible/ansible.cfg"
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        mkdir -p ~/.ssh
                        chmod 700 ~/.ssh

                        ssh-keygen -R "${EC2_IP}" || true

                        ansible-playbook \
                            -i ansible/hosts \
                            ansible/install.yml \
                            --ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
                            -vvvv
                    '''
                }
            }
        }

        stage('Verify Kubernetes Files') {
            steps {
                echo 'Checking Kubernetes manifest files...'

                sh '''
                    set -e

                    test -f kubernetes/namespace.yaml || {
                        echo "ERROR: kubernetes/namespace.yaml not found."
                        exit 1
                    }

                    test -f kubernetes/deployment.yaml || {
                        echo "ERROR: kubernetes/deployment.yaml not found."
                        exit 1
                    }

                    test -f kubernetes/service.yaml || {
                        echo "ERROR: kubernetes/service.yaml not found."
                        exit 1
                    }

                    echo "Kubernetes manifests are available."

                    ls -la kubernetes
                '''
            }
        }

        stage('Start Minikube') {
            steps {
                echo 'Starting Minikube on deployment EC2...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            "${SSH_USER}@${EC2_IP}" \
                            '
                                set -e

                                echo "Checking Docker access..."
                                docker version

                                if minikube status >/dev/null 2>&1
                                then
                                    echo "Minikube is already running."
                                else
                                    echo "Starting Minikube with Docker driver..."

                                    minikube start \
                                        --driver=docker \
                                        --cpus=2 \
                                        --memory=2200mb
                                fi

                                echo "Minikube status:"
                                minikube status

                                echo "Kubernetes node:"
                                kubectl get nodes -o wide
                            '
                    '''
                }
            }
        }

        stage('Copy Kubernetes Manifests') {
            steps {
                echo 'Copying Kubernetes manifests to deployment EC2...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            "${SSH_USER}@${EC2_IP}" \
                            "mkdir -p '${REMOTE_K8S_DIR}'"

                        scp \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            kubernetes/*.yaml \
                            "${SSH_USER}@${EC2_IP}:${REMOTE_K8S_DIR}/"

                        echo "Kubernetes manifests copied successfully."
                    '''
                }
            }
        }

        stage('Create Kubernetes Namespace') {
            steps {
                echo 'Creating Kubernetes namespace...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            "${SSH_USER}@${EC2_IP}" \
                            "
                                set -e

                                kubectl apply \
                                    -f '${REMOTE_K8S_DIR}/namespace.yaml'

                                kubectl get namespace '${K8S_NAMESPACE}'
                            "
                    '''
                }
            }
        }

        stage('Create ECR Pull Secret') {
    steps {
        echo 'Creating Kubernetes secret for private Amazon ECR...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    "AWS_ACCOUNT_ID='${AWS_ACCOUNT_ID}' \
                     AWS_DEFAULT_REGION='${AWS_DEFAULT_REGION}' \
                     K8S_NAMESPACE='${K8S_NAMESPACE}' \
                     bash -s" <<'REMOTE_SCRIPT'

set -euo pipefail

echo "Checking EC2 IAM role..."
aws sts get-caller-identity

echo "Getting ECR authorization password..."
ECR_PASSWORD="$(aws ecr get-login-password \
    --region "${AWS_DEFAULT_REGION}")"

if [ -z "${ECR_PASSWORD}" ]; then
    echo "ERROR: ECR password is empty."
    exit 1
fi

echo "ECR password received successfully."

kubectl delete secret \
    ecr-registry-secret \
    --namespace "${K8S_NAMESPACE}" \
    --ignore-not-found

kubectl create secret docker-registry \
    ecr-registry-secret \
    --namespace "${K8S_NAMESPACE}" \
    --docker-server="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com" \
    --docker-username="AWS" \
    --docker-password="${ECR_PASSWORD}"

echo "ECR pull secret created successfully."

kubectl get secret \
    ecr-registry-secret \
    --namespace "${K8S_NAMESPACE}"

REMOTE_SCRIPT
            '''
        }
    }
}

        stage('Prepare Kubernetes Deployment') {
            steps {
                echo 'Adding ECR image name to Kubernetes Deployment...'

                sh '''
                    set -e

                    FULL_IMAGE_NAME="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

                    echo "Image to deploy: ${FULL_IMAGE_NAME}"

                    sed \
                        "s|IMAGE_PLACEHOLDER|${FULL_IMAGE_NAME}|g" \
                        kubernetes/deployment.yaml \
                        > kubernetes/deployment-rendered.yaml

                    echo "Rendered Kubernetes Deployment:"
                    cat kubernetes/deployment-rendered.yaml
                '''
            }
        }

        stage('Copy Rendered Deployment') {
            steps {
                echo 'Copying rendered Kubernetes Deployment to EC2...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        scp \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            kubernetes/deployment-rendered.yaml \
                            "${SSH_USER}@${EC2_IP}:${REMOTE_K8S_DIR}/deployment-rendered.yaml"
                    '''
                }
            }
        }

        stage('Deploy Application to Kubernetes') {
            steps {
                echo 'Deploying Spring Boot container to Kubernetes...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            "${SSH_USER}@${EC2_IP}" \
                            "
                                set -e

                                kubectl apply \
                                    -f '${REMOTE_K8S_DIR}/deployment-rendered.yaml'

                                kubectl apply \
                                    -f '${REMOTE_K8S_DIR}/service.yaml'

                                echo 'Waiting for Kubernetes rollout...'

                                kubectl rollout status \
                                    deployment/'${K8S_DEPLOYMENT}' \
                                    --namespace '${K8S_NAMESPACE}' \
                                    --timeout=300s
                            "
                    '''
                }
            }
        }

        stage('Verify Kubernetes Resources') {
    steps {
        echo 'Checking Kubernetes Pods, Deployment and Service...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    "K8S_NAMESPACE='${K8S_NAMESPACE}' \
                     K8S_DEPLOYMENT='${K8S_DEPLOYMENT}' \
                     bash -s" <<'REMOTE_SCRIPT'

set -euo pipefail

echo "Kubernetes nodes:"
kubectl get nodes -o wide

echo "Kubernetes pods:"
kubectl get pods \
    --namespace "${K8S_NAMESPACE}" \
    -o wide

echo "Kubernetes deployment:"
kubectl get deployment \
    --namespace "${K8S_NAMESPACE}"

echo "Kubernetes service:"
kubectl get service \
    --namespace "${K8S_NAMESPACE}"

READY_REPLICAS="$(kubectl get deployment \
    "${K8S_DEPLOYMENT}" \
    --namespace "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}')"

AVAILABLE_REPLICAS="$(kubectl get deployment \
    "${K8S_DEPLOYMENT}" \
    --namespace "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.availableReplicas}')"

DESIRED_REPLICAS="$(kubectl get deployment \
    "${K8S_DEPLOYMENT}" \
    --namespace "${K8S_NAMESPACE}" \
    -o jsonpath='{.spec.replicas}')"

READY_REPLICAS="${READY_REPLICAS:-0}"
AVAILABLE_REPLICAS="${AVAILABLE_REPLICAS:-0}"
DESIRED_REPLICAS="${DESIRED_REPLICAS:-0}"

echo "Desired replicas: ${DESIRED_REPLICAS}"
echo "Ready replicas: ${READY_REPLICAS}"
echo "Available replicas: ${AVAILABLE_REPLICAS}"

if [ "${READY_REPLICAS}" -lt 1 ]; then
    echo "ERROR: No ready Kubernetes replicas found."

    echo "Deployment details:"
    kubectl describe deployment \
        "${K8S_DEPLOYMENT}" \
        --namespace "${K8S_NAMESPACE}"

    echo "Pod details:"
    kubectl describe pods \
        --namespace "${K8S_NAMESPACE}"

    echo "Recent events:"
    kubectl get events \
        --namespace "${K8S_NAMESPACE}" \
        --sort-by='.lastTimestamp'

    exit 1
fi

if [ "${AVAILABLE_REPLICAS}" -lt 1 ]; then
    echo "ERROR: No available Kubernetes replicas found."

    kubectl describe deployment \
        "${K8S_DEPLOYMENT}" \
        --namespace "${K8S_NAMESPACE}"

    exit 1
fi

if [ "${READY_REPLICAS}" -lt "${DESIRED_REPLICAS}" ]; then
    echo "ERROR: Not all desired replicas are ready."
    echo "Expected: ${DESIRED_REPLICAS}"
    echo "Ready: ${READY_REPLICAS}"

    kubectl describe deployment \
        "${K8S_DEPLOYMENT}" \
        --namespace "${K8S_NAMESPACE}"

    exit 1
fi

echo "Kubernetes deployment verification successful."
echo "All ${READY_REPLICAS} replicas are ready."

REMOTE_SCRIPT
            '''
        }
    }
}

        stage('Expose Kubernetes Application') {
            steps {
                echo 'Exposing Kubernetes service on EC2 port 8080...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            "${SSH_USER}@${EC2_IP}" \
                            "
                                set -e

                                sudo tee /etc/systemd/system/springboot-port-forward.service > /dev/null <<EOF
[Unit]
Description=Spring Boot Kubernetes Port Forward
After=network.target docker.service
Requires=docker.service

[Service]
User=ubuntu
Environment=HOME=/home/ubuntu
ExecStart=/usr/local/bin/kubectl port-forward --address=0.0.0.0 service/${K8S_SERVICE} ${HOST_PORT}:${SERVICE_PORT} --namespace ${K8S_NAMESPACE}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

                                sudo systemctl daemon-reload
                                sudo systemctl enable springboot-port-forward
                                sudo systemctl restart springboot-port-forward

                                sleep 5

                                sudo systemctl status \
                                    springboot-port-forward \
                                    --no-pager
                            "
                    '''
                }
            }
        }

        stage('Verify Application HTTP 200') {
            steps {
                echo 'Checking Kubernetes application backend HTTP status...'

                sshagent(credentials: ['agent-key']) {
                    sh '''
                        set -e

                        HTTP_STATUS="000"

                        for i in $(seq 1 20)
                        do
                            HTTP_STATUS=$(ssh \
                                -o StrictHostKeyChecking=no \
                                -o UserKnownHostsFile=/dev/null \
                                "${SSH_USER}@${EC2_IP}" \
                                "curl -s -o /dev/null -w '%{http_code}' http://localhost:${HOST_PORT}" \
                                || true)

                            echo "Attempt ${i}/20: HTTP status = ${HTTP_STATUS}"

                            if [ "${HTTP_STATUS}" = "200" ]; then
                                echo "Kubernetes application returned HTTP 200."
                                exit 0
                            fi

                            sleep 5
                        done

                        echo "ERROR: Kubernetes application did not return HTTP 200."

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            "${SSH_USER}@${EC2_IP}" \
                            "
                                kubectl get pods \
                                    --namespace '${K8S_NAMESPACE}' \
                                    -o wide

                                kubectl describe deployment \
                                    '${K8S_DEPLOYMENT}' \
                                    --namespace '${K8S_NAMESPACE}'

                                kubectl logs \
                                    deployment/'${K8S_DEPLOYMENT}' \
                                    --namespace '${K8S_NAMESPACE}' \
                                    --all-containers=true \
                                    || true

                                sudo journalctl \
                                    -u springboot-port-forward \
                                    --no-pager \
                                    -n 50 \
                                    || true
                            "

                        exit 1
                    '''
                }
            }
        }

stage('Verify Monitoring Files') {
    steps {
        echo 'Checking Prometheus, Grafana and dashboard files...'

        sh '''
            set -e

            test -f monitoring/prometheus.yaml
            test -f monitoring/grafana.yaml
            test -f monitoring/prometheus-rules.yaml 
            test -f monitoring/dashboards/cpu-dashboard.json
            test -f monitoring/dashboards/memory-dashboard.json
            test -f monitoring/systemd/prometheus-port-forward.service
            test -f monitoring/systemd/grafana-port-forward.service

            echo "All monitoring files are available."

            tree monitoring
        '''
    }
}

       stage('Copy Monitoring Files') {
    steps {
        echo 'Copying monitoring files to deployment EC2...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    "
                        mkdir -p /home/ubuntu/monitoring/dashboards
                        mkdir -p /home/ubuntu/monitoring/systemd
                    "

                scp \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    monitoring/prometheus-rules.yaml \
                    monitoring/prometheus.yaml \
                    monitoring/grafana.yaml \
                    "${SSH_USER}@${EC2_IP}:/home/ubuntu/monitoring/"

                scp \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    monitoring/dashboards/*.json \
                    "${SSH_USER}@${EC2_IP}:/home/ubuntu/monitoring/dashboards/"

                scp \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    monitoring/systemd/*.service \
                    "${SSH_USER}@${EC2_IP}:/home/ubuntu/monitoring/systemd/"
            '''
        }
    }
}

        
stage('Deploy Prometheus') {
    steps {
        echo 'Deploying Prometheus and recording rules to Minikube...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    '
                        set -e

                        echo "Applying Prometheus recording rules..."

                        kubectl apply \
                            -f /home/ubuntu/monitoring/prometheus-rules.yaml

                        echo "Applying Prometheus..."

                        kubectl apply \
                            -f /home/ubuntu/monitoring/prometheus.yaml

                        echo "Restarting Prometheus to load recording rules..."

                        kubectl rollout restart \
                            deployment/prometheus \
                            -n kube-system

                        kubectl rollout status \
                            deployment/prometheus \
                            -n kube-system \
                            --timeout=300s

                        kubectl get pods \
                            -n kube-system \
                            -l app=prometheus

                        kubectl get svc \
                            prometheus \
                            -n kube-system

                        echo "Prometheus deployment completed."
                    '
            '''
        }
    }
}


        stage('Create Grafana Dashboards ConfigMap') {
    steps {
        echo 'Creating Grafana dashboard ConfigMap...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    '
                        set -e

                        kubectl create configmap \
                            grafana-dashboards \
                            -n kube-system \
                            --from-file=/home/ubuntu/monitoring/dashboards/cpu-dashboard.json \
                            --from-file=/home/ubuntu/monitoring/dashboards/memory-dashboard.json \
                            --dry-run=client \
                            -o yaml \
                        | kubectl apply -f -
                    '
            '''
        }
    }
}

        stage('Deploy Grafana') {
    steps {
        echo 'Deploying Grafana to Minikube...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    '
                        set -e

                        kubectl apply \
                            -f /home/ubuntu/monitoring/grafana.yaml

                        kubectl rollout restart \
                            deployment/grafana \
                            -n kube-system

                        kubectl rollout status \
                            deployment/grafana \
                            -n kube-system \
                            --timeout=300s

                        kubectl get pods \
                            -n kube-system \
                            -l app=grafana

                        kubectl get svc \
                            grafana \
                            -n kube-system
                    '
            '''
        }
    }
}

        stage('Expose Monitoring Services') {
    steps {
        echo 'Configuring Prometheus and Grafana port-forward services...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    '
                        set -e

                        sudo cp \
                            /home/ubuntu/monitoring/systemd/prometheus-port-forward.service \
                            /etc/systemd/system/prometheus-port-forward.service

                        sudo cp \
                            /home/ubuntu/monitoring/systemd/grafana-port-forward.service \
                            /etc/systemd/system/grafana-port-forward.service

                        sudo systemctl daemon-reload

                        sudo systemctl enable prometheus-port-forward
                        sudo systemctl enable grafana-port-forward

                        sudo systemctl restart prometheus-port-forward
                        sudo systemctl restart grafana-port-forward

                        sleep 5

                        sudo systemctl status \
                            prometheus-port-forward \
                            --no-pager

                        sudo systemctl status \
                            grafana-port-forward \
                            --no-pager
                    '
            '''
        }
    }
}

       
        stage('Verify Monitoring') {
    steps {
        echo 'Verifying Prometheus, Grafana and Spring Boot pod metrics...'

        sshagent(credentials: ['agent-key']) {
            sh '''
                set -e

                ssh \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    "${SSH_USER}@${EC2_IP}" \
                    '
                        set -e

                        echo "============================================="
                        echo "1. Checking Prometheus readiness..."
                        echo "============================================="

                        curl \
                            --retry 20 \
                            --retry-delay 5 \
                            --retry-connrefused \
                            -f \
                            http://localhost:9090/-/ready

                        echo
                        echo "Prometheus is Ready."


                        echo
                        echo "============================================="
                        echo "2. Checking Grafana health..."
                        echo "============================================="

                        curl \
                            --retry 20 \
                            --retry-delay 5 \
                            --retry-connrefused \
                            -f \
                            http://localhost:3000/api/health

                        echo
                        echo "Grafana is Healthy."


                        echo
                        echo "============================================="
                        echo "3. Checking cAdvisor target..."
                        echo "============================================="

                        CADVISOR_RESPONSE=$(curl -G -s \
                            --data-urlencode '\''query=up{job="kubernetes-cadvisor"}'\'' \
                            http://localhost:9090/api/v1/query)

                        echo "${CADVISOR_RESPONSE}"

                        echo "${CADVISOR_RESPONSE}" | grep -q '"value".*"1"' || {
                            echo "ERROR: Kubernetes cAdvisor target is not UP."
                            exit 1
                        }

                        echo "cAdvisor target is UP."


                        echo
                        echo "============================================="
                        echo "4. Checking Spring Boot application pods..."
                        echo "============================================="

                        kubectl get pods \
                            -n springboot \
                            -l app=springboot-app \
                            -o wide

                        APP_POD_COUNT=$(kubectl get pods \
                            -n springboot \
                            -l app=springboot-app \
                            --field-selector=status.phase=Running \
                            --no-headers 2>/dev/null \
                            | wc -l)

                        echo "Running Spring Boot pods: ${APP_POD_COUNT}"

                        if [ "${APP_POD_COUNT}" -lt 1 ]; then
                            echo "ERROR: No running Spring Boot application pod found."
                            exit 1
                        fi


                        echo
                        echo "============================================="
                        echo "5. Checking Spring Boot CPU metrics..."
                        echo "============================================="

                        CPU_RESPONSE=$(curl -G -s \
                            --data-urlencode '\''query=sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="springboot",pod=~"springboot-app-.*"}[2m])) * 100'\'' \
                            http://localhost:9090/api/v1/query)

                        echo "${CPU_RESPONSE}"

                        echo "${CPU_RESPONSE}" | grep -q "springboot-app-" || {
                            echo "ERROR: Spring Boot CPU metrics not found in Prometheus."
                            exit 1
                        }

                        echo "Spring Boot CPU metrics are available."


                        echo
                        echo "============================================="
                        echo "6. Checking Spring Boot Memory metrics..."
                        echo "============================================="

                        MEMORY_RESPONSE=$(curl -G -s \
                            --data-urlencode '\''query=sum by (pod) (container_memory_working_set_bytes{namespace="springboot",pod=~"springboot-app-.*"})'\'' \
                            http://localhost:9090/api/v1/query)

                        echo "${MEMORY_RESPONSE}"

                        echo "${MEMORY_RESPONSE}" | grep -q "springboot-app-" || {
                            echo "ERROR: Spring Boot Memory metrics not found in Prometheus."
                            exit 1
                        }

                        echo "Spring Boot Memory metrics are available."


                        echo
                        echo "============================================="
                        echo "7. Checking Grafana dashboard ConfigMap..."
                        echo "============================================="

                        kubectl get configmap \
                            grafana-dashboards \
                            -n kube-system

                        DASHBOARD_COUNT=$(kubectl get configmap \
                            grafana-dashboards \
                            -n kube-system \
                            -o jsonpath="{.data}" \
                            | grep -o "dashboard.json" \
                            | wc -l \
                            || true)

                        echo "Grafana dashboard ConfigMap exists."


                        echo
                        echo "============================================="
                        echo "8. Checking dashboards inside Grafana pod..."
                        echo "============================================="

                        kubectl exec \
                            -n kube-system \
                            deployment/grafana \
                            -- ls -lh /etc/grafana/provisioned-dashboards

                        kubectl exec \
                            -n kube-system \
                            deployment/grafana \
                            -- test -f /etc/grafana/provisioned-dashboards/cpu-dashboard.json

                        kubectl exec \
                            -n kube-system \
                            deployment/grafana \
                            -- test -f /etc/grafana/provisioned-dashboards/memory-dashboard.json

                        echo "CPU and Memory dashboard files are mounted successfully."


                        echo
                        echo "============================================="
                        echo "MONITORING VERIFICATION SUCCESSFUL"
                        echo "============================================="
                        echo "Prometheus             : READY"
                        echo "Grafana                : HEALTHY"
                        echo "cAdvisor               : UP"
                        echo "Spring Boot Pods       : RUNNING"
                        echo "Spring Boot CPU Data   : AVAILABLE"
                        echo "Spring Boot Memory Data: AVAILABLE"
                        echo "Grafana Dashboards     : AVAILABLE"
                        echo "============================================="
                    '
            '''
        }
    }
}


        stage('Invoke Lambda URL Check') {
            steps {
                echo 'Invoking Lambda to hit the Kubernetes application URL...'

                sh '''
                    set -e

                    rm -f lambda-response.json

                    aws lambda invoke \
                        --function-name "${LAMBDA_NAME}" \
                        --region "${AWS_DEFAULT_REGION}" \
                        --cli-binary-format raw-in-base64-out \
                        --payload '{}' \
                        lambda-response.json

                    echo "Lambda response:"
                    cat lambda-response.json
                    echo
                '''
            }
        }

        stage('Verify Lambda Response') {
            steps {
                echo 'Checking Lambda response status...'

                sh '''
                    set -e

                    if grep -Eq \
                        '"statusCode"[[:space:]]*:[[:space:]]*200' \
                        lambda-response.json
                    then
                        echo "Lambda successfully reached the Kubernetes application."
                        echo "Lambda returned statusCode 200."
                    else
                        echo "ERROR: Lambda did not return statusCode 200."

                        echo "Lambda response:"
                        cat lambda-response.json

                        echo "Recent Lambda logs:"

                        aws logs tail \
                            "/aws/lambda/${LAMBDA_NAME}" \
                            --region "${AWS_DEFAULT_REGION}" \
                            --since 10m \
                            || true

                        exit 1
                    fi
                '''
            }
        }
    }

    post {
        success {
            echo '============================================='
            echo "Selected action: ${params.INFRA_ACTION}"
            echo 'Terraform operation completed successfully.'
            echo 'Ansible configuration completed successfully.'
            echo 'Minikube started successfully.'
            echo 'Application deployed to Kubernetes.'
            echo 'Kubernetes Pods are running.'
            echo 'Application returned HTTP 200.'
            echo 'Lambda URL test returned statusCode 200.'
            echo "Application URL: http://${env.EC2_IP}:${env.HOST_PORT}"
            echo "Prometheus URL: http://${env.EC2_IP}:9090"
            echo "Grafana URL: http://${env.EC2_IP}:3000"
            echo "Lambda Function: ${env.LAMBDA_NAME}"
            echo '============================================='
        }

        failure {
            echo '============================================='
            echo "Selected action: ${params.INFRA_ACTION}"
            echo 'Pipeline failed.'
            echo 'Check the first failed stage in Console Output.'
            echo '============================================='
        }

        always {
            echo 'Cleaning Jenkins workspace...'
            cleanWs()
        }
    }
}
 
