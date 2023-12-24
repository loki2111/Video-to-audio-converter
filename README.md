# Devops Project: video-converter
Converting mp4 videos to mp3 in a microservices architecture.

## Architecture

<p align="center">
  <img src="./Project-documentation/ProjectArchitecture.png" width="600" title="Architecture" alt="Architecture">
  </p>

## Deploying a Python-based Microservice Application on AWS EKS

### Introduction

This document provides a step-by-step guide for deploying a Python-based microservice application on AWS Elastic Kubernetes Service (EKS). The application comprises four major microservices: `auth-server`, `converter-module`, `database-server` (PostgreSQL and MongoDB), and `notification-server`.

### Prerequisites

Before you begin, ensure that the following prerequisites are met:

1. **Create an AWS Account:** If you do not have an AWS account, create one by following the steps [here](https://docs.aws.amazon.com/streams/latest/dev/setting-up.html).

2. **Install Terraform:** Terraform in a IAC tool for Automating the deployment of EKS Cluster, Roles, Security group, etc.

3. **Install Docker:** Docker is a Containerization Tool.

3. **Eks Cluster:** a managed Kubernetes service by AWS, simplifying the deployment, management, and scalability of containerized applications using Kubernetes. 

4. **Install Helm:** Helm is a Kubernetes package manager. Install Helm by following the instructions provided [here](https://helm.sh/docs/intro/install/).

5. **Python:** Ensure that Python is installed on your system. You can download it from the [official Python website](https://www.python.org/downloads/).

6. **AWS CLI:** Install the AWS Command Line Interface (CLI) following the official [installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

7. **Install kubectl:** Install the latest stable version of `kubectl` on your system. You can find installation instructions [here](https://kubernetes.io/docs/tasks/tools/).

8. **Databases:** Set up PostgreSQL and MongoDB for your application.


### High Level Flow of Application Deployment

Follow these steps to deploy your microservice application:

1. **MongoDB and PostgreSQL Setup:** Create databases and enable automatic connections to them.

2. **RabbitMQ Deployment:** Deploy RabbitMQ for message queuing, which is required for the `converter-module`.

3. **Create Queues in RabbitMQ:** Before deploying the `converter-module`, create two queues in RabbitMQ: `mp3` and `video`.

4. **Deploy Microservices:**
   - **auth-server:** Navigate to the `auth-server` manifest folder and apply the configuration.
   - **gateway-server:** Deploy the `gateway-server`.
   - **converter-module:** Deploy the `converter-module`. Make sure to provide your email and password in `converter/manifest/secret.yaml`.
   - **notification-server:** Configure email for notifications and two-factor authentication (2FA).

5. **Application Validation:** Verify the status of all components by running:
   ```bash
   kubectl get all
   ```

6. **Destroying the Infrastructure** 
   ```bash
   terraform destroy --auto-approve
   ```


### Low Level Steps


#### Cluster Creation (Automation by Terraform)

1. **Install Terraform:**
   - Run following commands.
```bash
    #!/bin/bash
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

    wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

    gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint

    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

    sudo apt update
    sudo apt-get install terraform -y
```



2. **Create Terraform Configuration files**
   - Note down required resources for EKS Cluster like Security group, IAM Roles, Policies, etc.
   - By this info create configuration files. ( main.tf in Terraform folder )
   - Some Commands of Terraform
Initialize a new or existing Terraform working directory, downloading required providers and modules.
```bash
terraform init
```
Check the syntax and validity of Terraform configuration files.
```bash
terraform validate
```
Generate an execution plan, showing what Terraform will do before making any changes.
```bash
terraform plan
```
Apply the changes described in the Terraform plan, automatically approving without manual confirmation.
```bash
terraform apply
```
Destroy the Terraform-managed infrastructure, automatically approving without manual confirmation.
```bash
terraform destroy
```
List all resources in the Terraform state.
```bash
terraform state list
```
Show the current state or a saved plan in human-readable format.
```bash
terraform show 
```

#### Cluster Creation (Manual)

1. **Log in to AWS Console:**
   - Access the AWS Management Console with your AWS account credentials.

2. **Create eks_cluster_role IAM Role**
   - Follow the steps mentioned in [this](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html) documentation using root user
   - After creating it will look like this:

   <p align="center">
  <img src="./Project-documentation/eks-cluster-role.png" width="600" title="eks-cluster-role" alt="eks-cluster-role">
  </p>

   - Please attach `AmazonEKS_CNI_Policy` explicitly if it is not attached by default

3. **Create Node Role - eks_worker_role**
   - Follow the steps mentioned in [this](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html#create-worker-node-role) documentation using root user
   - Please note that you do NOT need to configure any VPC CNI policy mentioned after step 5.e under Creating the Amazon EKS node IAM role
   - Simply attach the following policies to your role once you have created `AmazonEKS_CNI_Policy` , `AmazonEBSCSIDriverPolicy` , `AmazonEC2ContainerRegistryReadOnly` `AmazonEKSWorkerNodePolicy` incase it is not attached by default
   - Your AmazonEKSNodeRole will look like this: 

<p align="center">
  <img src="./Project-documentation/eks-worker-role.png" width="600" title="eks-worker-role" alt="eks-worker-role">
  </p>

4. **Open EKS Dashboard:**
   - Navigate to the Amazon EKS service from the AWS Console dashboard.

5. **Create EKS Cluster:**
   - Click "Create cluster."
   - Choose a name for your cluster. `video-to-audio`
   - Configure networking settings (VPC, subnets).
   - Choose the `eks_cluster_role` IAM role that was created above
   - Review and create the cluster.

6. **Cluster Creation:**
   - Wait for the cluster to provision, which may take several minutes.

7. **Cluster Ready:**
   - Once the cluster status shows as "Active," you can now create node groups.

#### Node Group Creation (manual)

1. In the "Compute" section, click on "Add node group."

2. Choose the AMI (default), instance type (e.g., t3.medium), and the number of nodes, choose remote access if you want to and select key.

3. Click "Create node group."

#### Adding inbound rules in Security Group of Nodes (manual)

**NOTE:** Ensure that all the necessary ports are open in the node security group.

<p align="center">
  <img src="./Project-documentation/inbound_rules_sg.png" width="600" title="Inbound_rules_sg" alt="Inbound_rules_sg">
  </p>

#### Enable EBS CSI Addon
1. enable addon `ebs csi` this is for enabling pvcs once cluster is created

<p align="center">
  <img src="./Project-documentation/ebs_addon.png" width="600" title="ebs_addon" alt="ebs_addon">
  </p>

#### Deploying your application on EKS Cluster

1. Clone the code from this repository.

2. Set the cluster context:
   ```
   aws eks update-kubeconfig --name <cluster_name> --region <aws_region>
   ```

### Commands

Here are some essential Kubernetes commands for managing your deployment:
   ```
   kubectl get nodes
   kubectl get all
   kubectl get ns
   kubectl get deploy
   kubectl get svc
   kubectl get pods -l <label=selector>
   kubectl describe <pod-name>
   kubectl describe deploy <deployment-name>
   kubectl logs <pod-name>
   kubectl edit deploy <deployment-name>
   kubectl scale --replicas==4 rs <replicaset-name>
   kubectl set image deployment/<deployment-name> <container-name/image-name>=<new-image-name-or updated version>
   kubectl apply -f .
   kubectl edit deployment
   helm install <name-for-deployment> .
   helm uninstall <name-of-deployment>
   helm list
   ```

### Helm Charts
- **Update manifest file values**
  Update values and its passwords, sql queries and its entries. also change the values other manifest file as you want.

### MongoDB

To install MongoDB, set the database username and password in `values.yaml`, then navigate to the MongoDB Helm chart folder and run:

```
cd Helm_charts/MongoDB
helm install mongo .
```

Connect to the MongoDB instance using:

```
mongosh mongodb://<username>:<pwd>@<nodeip>:30005/mp3s?authSource=admin
```

### PostgreSQL

Set the database username and password in `values.yaml`. Install PostgreSQL from the PostgreSQL Helm chart folder and initialize it with the queries in `init.sql`. For PowerShell users:

```
cd ..
cd Postgres
helm install postgres .
```

Connect to the Postgres database and copy all the queries from the "init.sql" file.
```
psql 'postgres://<username>:<pwd>@<nodeip>:30003/authdb'
```

### RabbitMQ

Deploy RabbitMQ by running:

```
helm install rabbitmq .
```

Ensure you have created two queues in RabbitMQ named `mp3` and `video`. To create queues, visit `<nodeIp>:30004>` and use default username `guest` and password `guest`
- Queries and Streams --> Name (mp3), Type(Classic), Add queue.

**NOTE:** Ensure that all the necessary ports are open in the node security group.


#### Install Docker

```
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl enable docker 
```

### Create Docker Images and push to Dockerhub.

1. Create Docker account.
2. Docker login in Terminal and add username password
```
docker login
```
3. Create docker image
```
docker build -t <dockerhub-username/docker-image-name> .
```
4. Push docker image to dockerhub
```
docker push <username/image-name>:tag
docker push lokesh2111/auth:latest
```
5. To tag image with username/imagename:tag if you missed earlier or misspelled 
```
docker tag SOURCE_IMAGE[:TAG] TARGET_IMAGE[:TAG]
```

### Apply the manifest file for each microservice:
- **Update manifest file values**
  Update secret, deployment files with your own need or just change password, docker image names.

- **Auth Service:**
  ```
  cd auth-service/manifest
  kubectl apply -f .
  ```

- **Gateway Service:**
  ```
  cd gateway-service/manifest
  kubectl apply -f .
  ```

- **Converter Service:**
  ```
  cd converter-service/manifest
  kubectl apply -f .
  ```

- **Notification Service:**
  ```
  cd notification-service/manifest
  kubectl apply -f .
  ```

### Application Validation

After deploying the microservices, verify the status of all components by running:

```
kubectl get all
```

### Notification Configuration


For configuring email notifications and two-factor authentication (2FA), follow these steps:

1. Go to your Gmail account and click on your profile.

2. Click on "Manage Your Google Account."

3. Navigate to the "Security" tab on the left side panel.

4. Enable "2-Step Verification."

5. Search for the application-specific passwords. You will find it in the settings.

6. Click on "Other" and provide your name.

7. Click on "Generate" and copy the generated password.

8. Paste this generated password in `converter/manifest/secret.yaml` along with your email.

Run the application through the following API calls: 

# API Definition

- **Login Endpoint**
  ```http request
  POST http://nodeIP:30002/login
  ```

  ```console
  curl -X POST http://nodeIP:30002/login -u <email>:<password>
  ``` 
  Expected output: success!
  You will get JWT token note and use it in follwing API Calls

- **Upload Endpoint**
  ```http request
  POST http://nodeIP:30002/upload
  ```

  ```console
   curl -X POST -F 'file=@./minions-christmas.mp4' -H 'Authorization: Bearer <JWT Token>' http://nodeIP:30002/upload
  ``` 
  
  Check if you received the ID on your email.

- **Download Endpoint**
  ```http request
  GET http://nodeIP:30002/download?fid=<Generated file identifier>
  ```
  ```console
   curl --output minions-christmas.mp3 -X GET -H 'Authorization: Bearer <JWT Token>' "http://nodeIP:30002/download?fid=<Generated fid>"
  ``` 

## Destroying the Infrastructure (Automated-Process by Terraform)

  ```bash
  terraform destroy --auto-approve
  ``` 

## Destroying the Infrastructure (Manual-Process)

To clean up the infrastructure, follow these steps:

1. **Delete the Node Group:** Delete the node group associated with your EKS cluster.

2. **Delete the EKS Cluster:** Once the nodes are deleted, you can proceed to delete the EKS cluster itself.
