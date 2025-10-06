# Jenkins CI/CD Pipeline on AWS - Complete Setup Guide

A comprehensive guide to building a production-ready Jenkins CI/CD pipeline that automatically deploys a Flask application to AWS EC2 using Docker, ECR, and CodeDeploy.

## 📋 Table of Contents
- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Phase 1: Jenkins Server Setup](#phase-1-jenkins-server-setup)
- [Phase 2: GitHub Repository Setup](#phase-2-github-repository-setup)
- [Phase 3: AWS ECR Configuration](#phase-3-aws-ecr-configuration)
- [Phase 4: Target EC2 Instance Setup](#phase-4-target-ec2-instance-setup)
- [Phase 5: AWS CodeDeploy Setup](#phase-5-aws-codedeploy-setup)
- [Phase 6: Deployment Scripts](#phase-6-deployment-scripts)
- [Phase 7: Jenkins Pipeline Configuration](#phase-7-jenkins-pipeline-configuration)
- [Phase 8: Jenkins Credentials Setup](#phase-8-jenkins-credentials-setup)
- [Phase 9: Create Jenkins Pipeline Job](#phase-9-create-jenkins-pipeline-job)
- [Phase 10: Testing & Automation](#phase-10-testing--automation)
- [Troubleshooting](#troubleshooting)

## Project Overview

This project demonstrates a real-world DevOps workflow using:
- **Jenkins** for CI/CD automation
- **GitHub** for source control
- **Docker** for containerization
- **AWS ECR** for container registry
- **AWS CodeDeploy** for automated deployment
- **AWS EC2** for hosting the application

### What Gets Built

A fully automated pipeline that:
1. Pulls code from GitHub on every push
2. Runs automated tests
3. Builds a Docker image
4. Pushes the image to AWS ECR
5. Deploys to EC2 using AWS CodeDeploy

## Architecture

```
GitHub Push → Jenkins Pipeline → Run Tests → Build Docker Image 
→ Push to ECR → CodeDeploy → Deploy to EC2 → Running Application
```

## Prerequisites

Before starting, ensure you have:
- AWS account with appropriate permissions
- GitHub account
- SSH client (Terminal/Git Bash)
- Basic knowledge of Linux commands
- AWS IAM user with these policies:
  - `AmazonEC2ContainerRegistryFullAccess`
  - `AWSCodeDeployFullAccess`
  - `AmazonEC2FullAccess`
  - `IAMFullAccess`
  - `AmazonS3FullAccess`

---

## Phase 1: Jenkins Server Setup

### 1.1 Launch EC2 Instance for Jenkins

1. Go to **AWS Console** → **EC2** → **Launch Instance**

2. **Configure instance:**
   - **Name:** `Jenkins-Server`
   - **AMI:** Amazon Linux 2023 AMI (free tier eligible)
   - **Instance type:** `t2.medium` (Jenkins needs at least 2GB RAM)
   - **Key pair:** Create or select existing key pair (e.g., `jenkins-key`)

3. **Network settings:**
   - **VPC:** Default
   - **Subnet:** Default
   - **Auto-assign public IP:** Enable
   - **Create security group:**
     - **Security group name:** `jenkins-SG`
     - **Description:** Security group for Jenkins server
     
4. **Inbound rules:**
   - **Rule 1:** SSH | TCP | Port 22 | Source: My IP (or 0.0.0.0/0)
   - **Rule 2:** Custom TCP | TCP | Port 8080 | Source: 0.0.0.0/0
   - **Rule 3:** HTTP | TCP | Port 80 | Source: 0.0.0.0/0

5. **Storage:** 8 GiB gp3

6. Click **Launch Instance**

### 1.2 Connect to EC2 and Install Jenkins

1. **SSH into your EC2 instance:**

```bash
ssh -i /path/to/your-keypair.pem ec2-user@<EC2-Public-IP-Address>
```

2. **Install required software** (execute commands one by one):

```bash
# Update system
sudo yum update -y

# Install Git
sudo yum install git -y
git --version

# Install Java 17 (required for Jenkins)
sudo yum install java-17-amazon-corretto-devel -y
java -version

# Install Docker
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker

# Add ec2-user to docker group (to run docker without sudo)
sudo usermod -aG docker ec2-user

# Install Jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum install jenkins -y

# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Restart Jenkins to apply group changes
sleep 5
sudo systemctl restart jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

3. **Copy the initial admin password** (you'll need it in the next step)

### 1.3 Access and Configure Jenkins

1. **Open Jenkins in browser:**
   - URL: `http://<YOUR-EC2-PUBLIC-IP>:8080`

2. **Unlock Jenkins:**
   - Paste the initial admin password
   - Click **Continue**

3. **Install plugins:**
   - Click **Install suggested plugins**
   - Wait for installation to complete

4. **Create Admin User:**
   - Username: (your choice)
   - Password: (your choice)
   - Full name: (your choice)
   - Email: (your choice)
   - Click **Save and Continue**

5. **Instance Configuration:**
   - Keep the default Jenkins URL
   - Click **Save and Finish**
   - Click **Start using Jenkins**

### 1.4 Install Required Jenkins Plugins

1. **Go to:** Dashboard → **Manage Jenkins** → **Plugins**

2. **Click on "Available plugins" tab**

3. **Search and install these plugins:**
   - Docker Pipeline
   - AWS Credentials
   - Pipeline: AWS Steps
   - GitHub Integration Plugin
   - Amazon ECR

4. **Check:** "Restart Jenkins when installation is complete and no jobs are running"

5. **Wait for Jenkins to restart and log back in**

---

## Phase 2: GitHub Repository Setup

### 2.1 Create GitHub Repository

1. Go to **GitHub** → **New Repository**
2. **Configure:**
   - **Repository name:** `jenkins-aws-cicd`
   - **Description:** Jenkins CI/CD pipeline with AWS deployment
   - **Visibility:** Public (or Private)
   - **Do NOT initialize** with README, .gitignore, or license
3. Click **Create repository**

### 2.2 Create Project Locally

Open your terminal (Git Bash on Windows) and execute:

```bash
# Create project directory
mkdir jenkins-aws-cicd
cd jenkins-aws-cicd

# Initialize git
git init

# Create folder structure
mkdir app
mkdir scripts
```

### 2.3 Create Application Files

**Create `app/app.py`:**

```python
from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return f"Hello from Jenkins CI/CD! Version: {os.getenv('APP_VERSION', '1.0')}"

@app.route('/health')
def health():
    return {"status": "healthy"}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**Create `app/requirements.txt`:**

```txt
Flask==3.0.0
pytest==7.4.3
```

**Create `app/test_app.py`:**

```python
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_hello(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b"Hello from Jenkins CI/CD" in response.data

def test_health(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'
```

**Create `Dockerfile`:**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 5000

CMD ["python", "app.py"]
```

**Create `.dockerignore`:**

```
__pycache__
*.pyc
*.pyo
*.pyd
.pytest_cache
.git
*.md
Jenkinsfile
scripts/
appspec.yml
```

**Create `.gitignore`:**

```
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/
.pytest_cache/
.DS_Store
*.swp
*.swo
.idea/
.vscode/
```

### 2.4 Verify File Structure

Your project should look like this:

```
jenkins-aws-cicd/
├── .git/
├── .gitignore
├── .dockerignore
├── Dockerfile
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── test_app.py
└── scripts/
    (empty for now)
```

### 2.5 Push Code to GitHub

```bash
# Add all files
git add .

# Commit
git commit -m "Initial commit: Flask app with Docker"

# Add remote (replace YOUR-USERNAME with your GitHub username)
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/jenkins-aws-cicd.git

# Push to GitHub
git push -u origin main
```

### 2.6 Verify on GitHub

Check your GitHub repository and verify all files are present.

---

## Phase 3: AWS ECR Configuration

### 3.1 Create ECR Repository

1. Go to **AWS Console** → **ECR** → **Get Started** (or **Create repository**)

2. **Configure repository:**
   - **Visibility settings:** Private
   - **Repository name:** `jenkins-cicd-app`
   - **Tag immutability:** Disabled
   - **Image scan settings:** Check "Scan on push" (optional)
   - **Encryption:** Keep default (AES-256)

3. Click **Create repository**

4. **Copy and save the Repository URI** (format: `<account-id>.dkr.ecr.<region>.amazonaws.com/jenkins-cicd-app`)

### 3.2 Set Up ECR Lifecycle Policy (Optional - Saves Costs)

1. In ECR, click on your `jenkins-cicd-app` repository
2. Click **Lifecycle Policy** tab
3. Click **Create rule**
4. **Configure rule:**
   - **Rule priority:** 1
   - **Rule description:** Keep only 5 most recent images
   - **Image status:** Any
   - **Match criteria:** Image count more than 5
   - **Action:** Expire
5. Click **Save**

### 3.3 Note Your AWS Information

Save these details for later:
- **AWS Account ID:** Your 12-digit account ID
- **AWS Region:** e.g., `us-west-2`
- **ECR Repository URI:** `<account-id>.dkr.ecr.<region>.amazonaws.com/jenkins-cicd-app`

---

## Phase 4: Target EC2 Instance Setup

### 4.1 Create IAM Role for EC2 Instance

1. Go to **AWS Console** → **IAM** → **Roles** → **Create role**

2. **Select trusted entity:**
   - **Trusted entity type:** AWS service
   - **Use case:** EC2

3. **Add permissions** (search and select):
   - `AmazonEC2ContainerRegistryReadOnly`
   - `AmazonEC2RoleforAWSCodeDeploy`
   - `AmazonS3ReadOnlyAccess`

4. **Name the role:**
   - **Role name:** `CodeDeployEC2Role`
   - **Description:** Role for EC2 instances to work with CodeDeploy and ECR

5. Click **Create role**

### 4.2 Create IAM Role for CodeDeploy Service

1. **IAM** → **Roles** → **Create role**

2. **Select trusted entity:**
   - **Trusted entity type:** AWS service
   - **Use case:** CodeDeploy

3. **Add permissions:**
   - The policy `AWSCodeDeployRole` should be automatically selected

4. **Name the role:**
   - **Role name:** `CodeDeployServiceRole`
   - **Description:** Service role for AWS CodeDeploy

5. Click **Create role**

### 4.3 Launch Target EC2 Instance

1. **AWS Console** → **EC2** → **Launch Instance**

2. **Configure:**
   - **Name:** `App-Server`
   - **Tags:** Key = `Environment`, Value = `Production`
   - **AMI:** Amazon Linux 2023 AMI
   - **Instance type:** `t2.micro` (free tier)
   - **Key pair:** Select your existing key pair

3. **Network settings:**
   - **VPC:** Default
   - **Subnet:** Default
   - **Auto-assign public IP:** Enable
   - **Create security group:**
     - **Name:** `app-server-SG`
     - **Description:** Security group for application server

4. **Inbound rules:**
   - **Rule 1:** SSH | TCP | Port 22 | Source: My IP
   - **Rule 2:** HTTP | TCP | Port 80 | Source: 0.0.0.0/0
   - **Rule 3:** Custom TCP | TCP | Port 5000 | Source: 0.0.0.0/0

5. **Advanced details:**
   - Scroll to **IAM instance profile**
   - Select: `CodeDeployEC2Role`
   
   - Scroll to **User data** (at the bottom)
   - Paste this script (⚠️ **Replace `us-west-2` with your region if different**):

```bash
#!/bin/bash
yum update -y
yum install -y ruby wget docker

# Start Docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install CodeDeploy agent
cd /home/ec2-user
wget https://aws-codedeploy-us-west-2.s3.us-west-2.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl start codedeploy-agent
systemctl enable codedeploy-agent
```

6. Click **Launch Instance**

7. **Note the Public IPv4 address**

### 4.4 Verify CodeDeploy Agent is Running

1. **SSH into the App-Server:**

```bash
ssh -i /path/to/your-keypair.pem ec2-user@<App-Server-Public-IP>
```

2. **Check CodeDeploy agent status:**

```bash
sudo systemctl status codedeploy-agent
```

You should see: `active (running)` in green

3. **Check Docker:**

```bash
docker --version
sudo systemctl status docker
```

Both should be installed and running.

4. **Exit the SSH session:**

```bash
exit
```

---

## Phase 5: AWS CodeDeploy Setup

### 5.1 Create CodeDeploy Application

1. **AWS Console** → **CodeDeploy** → **Applications** → **Create application**

2. **Configure:**
   - **Application name:** `jenkins-cicd-app`
   - **Compute platform:** EC2/On-premises

3. Click **Create application**

### 5.2 Create Deployment Group

1. In your application, click **Create deployment group**

2. **Configure:**
   - **Deployment group name:** `production`
   - **Service role:** Select `CodeDeployServiceRole`

3. **Deployment type:**
   - Select: **In-place**

4. **Environment configuration:**
   - Select: **Amazon EC2 instances**
   - **Tag group 1:**
     - Key: `Environment`
     - Value: `Production`
   - You should see: "1 unique matched instance"

5. **Agent configuration with AWS Systems Manager:**
   - Keep default: **Never**

6. **Deployment settings:**
   - **Deployment configuration:** `CodeDeployDefault.AllAtOnce`

7. **Load balancer:**
   - **Uncheck** "Enable load balancing"

8. Click **Create deployment group**

### 5.3 Verify Deployment Group

- You should see deployment group "production" listed
- Click on it to verify:
  - ✅ Status: Active
  - ✅ Target instances: 1 instance
  - ✅ Service role: CodeDeployServiceRole

---

## Phase 6: Deployment Scripts

### 6.1 Create `appspec.yml`

In your local `jenkins-aws-cicd` directory, create `appspec.yml`:

```yaml
version: 0.0
os: linux
hooks:
  ApplicationStop:
    - location: scripts/stop_container.sh
      timeout: 300
      runas: root
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: root
  ApplicationStart:
    - location: scripts/start_container.sh
      timeout: 300
      runas: root
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 300
      runas: root
```

### 6.2 Create Deployment Scripts

Create 4 shell scripts in the `scripts/` folder:

**`scripts/install_dependencies.sh`:**

```bash
#!/bin/bash
set -e

echo "Installing dependencies..."

# Ensure Docker is running
systemctl start docker

# Login to ECR (⚠️ Replace with your account ID and region)
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin <YOUR-ACCOUNT-ID>.dkr.ecr.us-west-2.amazonaws.com

echo "Dependencies installed successfully"
```

**`scripts/stop_container.sh`:**

```bash
#!/bin/bash

echo "Stopping existing container..."

# Stop and remove existing container (ignore errors if it doesn't exist)
docker stop flask-app 2>/dev/null || echo "Container not running"
docker rm flask-app 2>/dev/null || echo "Container not found"

echo "Container cleanup completed"
```

**`scripts/start_container.sh`:**

```bash
#!/bin/bash
set -e

echo "Starting new container..."

# Pull latest image from ECR (⚠️ Replace with your account ID and region)
docker pull <YOUR-ACCOUNT-ID>.dkr.ecr.us-west-2.amazonaws.com/jenkins-cicd-app:latest

# Run container
docker run -d \
  --name flask-app \
  -p 80:5000 \
  --restart unless-stopped \
  <YOUR-ACCOUNT-ID>.dkr.ecr.us-west-2.amazonaws.com/jenkins-cicd-app:latest

echo "Container started successfully"
```

**`scripts/validate_service.sh`:**

```bash
#!/bin/bash
set -e

echo "Validating service..."

# Wait for app to start
sleep 10

# Check if container is running
if ! docker ps | grep flask-app; then
  echo "ERROR: Container is not running"
  exit 1
fi

# Health check
if ! curl -f http://localhost/health; then
  echo "ERROR: Health check failed"
  exit 1
fi

echo "Service validation successful!"
```

⚠️ **IMPORTANT:** In all scripts above, replace:
- `<YOUR-ACCOUNT-ID>` with your AWS Account ID
- `us-west-2` with your AWS region if different

### 6.3 Verify File Structure

```
jenkins-aws-cicd/
├── .git/
├── .gitignore
├── .dockerignore
├── Dockerfile
├── appspec.yml          ← NEW
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── test_app.py
└── scripts/             ← NEW
    ├── install_dependencies.sh
    ├── stop_container.sh
    ├── start_container.sh
    └── validate_service.sh
```

### 6.4 Push to GitHub

```bash
# Add new files
git add appspec.yml scripts/

# Commit
git commit -m "Add CodeDeploy configuration and deployment scripts"

# Push to GitHub
git push origin main
```

---

## Phase 7: Jenkins Pipeline Configuration

### 7.1 Create Jenkinsfile

In your local `jenkins-aws-cicd` directory, create `Jenkinsfile` at the root:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = '<YOUR-ACCOUNT-ID>'
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/jenkins-cicd-app"
        APP_NAME = 'jenkins-cicd-app'
        DEPLOYMENT_GROUP = 'production'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "✓ Code checked out from GitHub"
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    docker.image('python:3.11-slim').inside('-u root:root') {
                        sh '''
                            cd app
                            pip install -r requirements.txt
                            pytest test_app.py -v
                        '''
                    }
                }
                echo "✓ Tests passed successfully"
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    dockerImage = docker.build("${ECR_REPO}:${IMAGE_TAG}")
                    docker.build("${ECR_REPO}:latest")
                }
                echo "✓ Docker image built successfully"
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REPO}
                            
                            docker push ${ECR_REPO}:${IMAGE_TAG}
                            docker push ${ECR_REPO}:latest
                        """
                    }
                }
                echo "✓ Docker image pushed to ECR"
            }
        }
        
        stage('Deploy with CodeDeploy') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        // Create deployment bundle
                        sh """
                            zip -r app-${BUILD_NUMBER}.zip appspec.yml scripts/
                            aws s3 mb s3://jenkins-cicd-deployments-${AWS_ACCOUNT_ID} || true
                            aws s3 cp app-${BUILD_NUMBER}.zip s3://jenkins-cicd-deployments-${AWS_ACCOUNT_ID}/
                        """
                        
                        // Create deployment
                        sh """
                            aws deploy create-deployment \
                              --application-name ${APP_NAME} \
                              --deployment-group-name ${DEPLOYMENT_GROUP} \
                              --deployment-config-name CodeDeployDefault.AllAtOnce \
                              --description "Deployment from Jenkins Build ${BUILD_NUMBER}" \
                              --s3-location bucket=jenkins-cicd-deployments-${AWS_ACCOUNT_ID},bundleType=zip,key=app-${BUILD_NUMBER}.zip
                        """
                    }
                }
                echo "✓ Deployment initiated via CodeDeploy"
            }
        }
    }
    
    post {
        success {
            echo '=========================================='
            echo '✓ Pipeline completed successfully!'
            echo '=========================================='
        }
        failure {
            echo '=========================================='
            echo '✗ Pipeline failed!'
            echo '=========================================='
        }
        always {
            cleanWs()
        }
    }
}
```

⚠️ **IMPORTANT:** Replace:
- `<YOUR-ACCOUNT-ID>` with your AWS Account ID
- `us-west-2` with your AWS region if different

### 7.2 Push Jenkinsfile to GitHub

```bash
# Add Jenkinsfile
git add Jenkinsfile

# Commit
git commit -m "Add Jenkinsfile for CI/CD pipeline"

# Push to GitHub
git push origin main
```

---

## Phase 8: Jenkins Credentials Setup

### 8.1 Add AWS Credentials to Jenkins

1. **Jenkins Dashboard** → **Manage Jenkins** → **Credentials** → **System** → **Global credentials (unrestricted)** → **Add Credentials**

2. **Configure AWS Credentials:**
   - **Kind:** AWS Credentials
   - **ID:** `aws-credentials` (⚠️ exactly as written - matches Jenkinsfile)
   - **Description:** AWS credentials for ECR and CodeDeploy
   - **Access Key ID:** Your AWS Access Key ID
   - **Secret Access Key:** Your AWS Secret Access Key

3. Click **Create**

### 8.2 Verify Credentials

- You should see "aws-credentials" in the credentials list
- Verify:
  - ✅ ID: aws-credentials
  - ✅ Kind: AWS Credentials
  - ✅ Scope: Global

### 8.3 Add GitHub Credentials (Optional)

If your repository is private:

1. **Add Credentials** → **Username with password**
   - **Username:** Your GitHub username
   - **Password:** Your GitHub Personal Access Token
   - **ID:** `github-credentials`
   - **Description:** GitHub credentials

---

## Phase 9: Create Jenkins Pipeline Job

### 9.1 Create New Pipeline Job

1. **Jenkins Dashboard** → **New Item**
2. **Enter name:** `jenkins-aws-cicd-pipeline`
3. **Select:** Pipeline
4. Click **OK**

### 9.2 Configure Pipeline Job

**General Section:**
- **Description:** `CI/CD pipeline for Flask app deployment to AWS EC2 using CodeDeploy`
- **Check:** "GitHub project"
- **Project URL:** `https://github.com/YOUR-USERNAME/jenkins-aws-cicd/`
  (Replace YOUR-USERNAME)

**Build Triggers:**
- **Check:** "GitHub hook trigger for GITScm polling"

**Pipeline Section:**
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** `https://github.com/YOUR-USERNAME/jenkins-aws-cicd.git`
- **Credentials:** Select `github-credentials` (or "- none -" if public repo)
- **Branch Specifier:** `*/main`
- **Script Path:** `Jenkinsfile`

Click **Save**

### 9.3 Configure Git in Jenkins (If Needed)

If you encounter Git issues:

1. **Manage Jenkins** → **Tools**
2. Scroll to **Git** section
3. If not listed, click **Add Git**
   - **Name:** Default
   - **Path to Git executable:** `/usr/bin/git`
4. Click **Apply** and **Save**

---

## Phase 10: Testing & Automation

### 10.1 First Manual Build

1. Go to your pipeline: `jenkins-aws-cicd-pipeline`
2. Click **Build Now**
3. Watch the build progress in **Build History**
4. Click on the build number → **Console Output** to see logs

**Expected stages:**
- ✅ Checkout
- ✅ Run Tests
- ✅ Build Docker Image
- ✅ Push to ECR
- ✅ Deploy with CodeDeploy

### 10.2 Verify Deployment

1. **Check CodeDeploy:**
   - AWS Console → CodeDeploy → Applications → jenkins-cicd-app → production
   - You should see a successful deployment

2. **Test the application:**
   - Open browser: `http://<App-Server-Public-IP>`
   - You should see: "Hello from Jenkins CI/CD! Version: 1.0"
   - Test health endpoint: `http://<App-Server-Public-IP>/health`

### 10.3 Setup GitHub Webhook for Auto-Trigger

1. **Get Jenkins webhook URL:**
   - Format: `http://<Jenkins-Server-Public-IP>:8080/github-webhook/`

2. **Add webhook in GitHub:**
   - Your repository → **Settings** → **Webhooks** → **Add webhook**
   - **Payload URL:** `http://<Jenkins-Server-Public-IP>:8080/github-webhook/`
   - **Content type:** application/json
   - **Which events:** Just the push event
   - Click **Add webhook**

3. **Test automatic trigger:**
   - Make a change to your code (e.g., edit `app.py`)
   - Commit and push:

```bash
git add .
git commit -m "Test automatic build"
git push origin main
```

Jenkins should automatically start building within seconds!

---

## Troubleshooting

### Common Issues and Solutions

**Issue: Jenkins can't pull from GitHub**
- Verify GitHub URL is correct
- Check if repository is private (add credentials)
- Test: `git ls-remote <your-repo-url> HEAD`

**Issue: Docker permission denied**
- Ensure jenkins user is in docker group: `sudo usermod -aG docker jenkins`
- Restart Jenkins: `sudo systemctl restart jenkins`

**Issue: ECR push fails**
- Verify AWS credentials in Jenkins
- Check IAM permissions
- Verify region in Jenkinsfile matches your ECR region

**Issue: CodeDeploy agent not running**
- SSH into App-Server
- Check status: `sudo systemctl status codedeploy-agent`
- Restart: `sudo systemctl restart codedeploy-agent`
- Check logs: `sudo cat /var/log/aws/codedeploy-agent/codedeploy-agent.log`

**Issue: Deployment fails**
- Check CodeDeploy logs on App-Server: `/opt/codedeploy-agent/deployment-root/deployment-logs/`
- Verify IAM roles are attached correctly
- Ensure scripts have correct AWS Account ID and region

**Issue: Container not starting**
- SSH into App-Server
- Check Docker logs: `docker logs flask-app`
- Verify ECR image exists: `aws ecr list-images --repository-name jenkins-cicd-app`

---

## 🎉 Congratulations!

You've successfully built a production-ready CI/CD pipeline! Every time you push code to GitHub, it will automatically:
1. Run tests
2. Build a Docker image
3. Push to AWS ECR
4. Deploy to EC2

This is the same workflow used by DevOps engineers in real companies.

## Next Steps

- Add more comprehensive tests
- Implement blue/green deployment
- Add monitoring with CloudWatch
- Set up application load balancer
- Implement auto-scaling

## Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [AWS CodeDeploy Documentation](https://docs.aws.amazon.com/codedeploy/)
- [Docker Documentation](https://docs.docker.com/)

---

**Made with ❤️ for DevOps learners**

