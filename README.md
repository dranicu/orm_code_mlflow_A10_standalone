# **ORM_stack_a10_gpu_with_mlflow_and_jupyter**

## **Oracle Resource Manager (ORM) Stack to deploy an A10* shape with one or more GPUs to test mlflow with jupyterlab*

- [Prerequisites](#prerequisites)
- [Intallation](#installation)
- [Note](#note)
- [System_monitoring](#system_monitoring)
- [Jupyter_access](#jupyter_access)
- [Notebook](#notebook)
- [Mlflow Artifacts to OCI bucket](#storing-mlflow-artifacts-to-oci-bucket)


## Prerequisites
- Virtual cloud network (VCN) and subnet. If you do not already have a VCN see [here](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/create_vcn.htm). Use the wizard by selecting "Start VCN Wizard." For subnets, see [here](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/create_subnet.htm).
- `customer_access_key` and `customer_secret_key`. If you don't already have these, then see [here](https://docs.oracle.com/en-us/iaas/Content/Identity/access/using-the-console.htm#create-customer-secret-key). Record these keys in a password manager.
- SSH Keys. [link](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key). Tested with RSA only. Might work with ed25519?
- Access to GPU. See [Limits, Quotas, and Usage](https://cloud.oracle.com/limits)

## Installation
- Create a stack from the ORM in Oracle Cloud Infrastructure (OCI). Use this [link](https://cloud.oracle.com/resourcemanager/stacks).
- There are 3 steps to create a stack. Tips for each step:
    - *Stack information*: Use this repo/directory for Terraform configuration source
    - *Configure variables*: Select Oracle Linux for Operating System. Select 8 for Operating System Version.
    - *Review*: Select "Run apply" under "Run apply on the created stack?"
- If stack created properly, then you should see `VM_PRIV_IP` and `VM_PUB_IP` in Logs and Outputs. You will also have a new instance in [Instances](https://cloud.oracle.com/compute/instances)
- Connect to the instance via SSH key. See previous step for `VM_PUB_IP`. On MacOS, you can do:

    ```
    ssh -i <path_to_private_ssh_key> opc@<VM_PUB_IP>
    ```
    When asked `Are you sure you want to continue connecting (yes/no/[fingerprint])?`, type `yes` and press enter.  You know you're successful when you're on the cloud instance command line `[opc@a10-gpu ~]$`.

- Once the instance is created, the `cloudinit.sh` script will start running. Wait for cloud init completion. See [System Monitoring](#system_monitoring)
- Allow firewall access to be able launch the jupyter notebook interface, commands detailed for both Oracle Linux and Ubuntu in the [Jupyter_access](#jupyter_access) section below.
- Allow ingress on subnet used for instance. Add ingress rules for the following:
    - Your own IP address (source = <your_ip_address>/32)
    - Jupyter (source = <your_ip_address>/32, IP Protocol = TCP, Destintation Port Range = 8888)
    - MLFlow (source = <your_ip_address>/32, IP Protocol = TCP, Destintation Port Range = 5000)
- Start Jupyter notebook and MLFlow in cloud instance. Make sure you have activated the conda environment `myenv` with something like `conda activate myenv`. Then do:
    - Jupyter:
        ```
        jupyter notebook --ip=0.0.0.0 --port=8888 > ~/jupyter.log 2>&1 &
        ```
    - MLFlow:
        ```
        mlflow server --host 0.0.0.0 --port 5000 --artifacts-destination \$MLFLOW_ARTIFACT_URI > ~/mlflow.log 2>&1 &
        ```
- Ensure that Jupyter notebook has `mlflow.set_tracking_uri("http://localhost:5000")`

- **Jupyter notebook has already configured triton_example_kernel environment**
- **you can create additional environmetns if needed and then if you need to switch between them go to Kernel -> Change kernel -> Select [new_example_that_you_create  or triton_example_kernel]**


## NOTE
- **the code deploys an A10* shape with one or more GPUs**
- **based on your need you have the option to either create a new VCN and subnet or you ca use an existing VCN and a subnet where the VM will be deployed**
- **it will add a freeform TAG : "GPU_TAG"= "A10-1"**
- **the boot vol is 500 GB**
- **the cloudinit will do all the steps needed to build and to start mlflow based on a docker image and in addtion will install also Jupyter notebook**

## System_monitoring
- **Some commands to check the progress of cloudinit completion and GPU resource utilization:**
```
monitor cloud init completion: tail -f /var/log/cloud-init-output.log
monitor single GPU: nvidia-smi dmon -s mu -c 100
                    watch -n 2 'nvidia-smi'
monitor the system in general: sar 3 1000
```
## Jupyter_access
### Enable access to Jupyter on both Oracle Linux and Ubuntu:

- **Oracle Linux:** Run these commands in cloud instance
```
sudo firewall-cmd --zone=public --permanent --add-port 8888/tcp && sudo firewall-cmd --zone=public --permanent --add-port 5000/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```
!!! in case that you reboot the system you will need to manually start jupyter notebook and mlflow:
make sure check the following files from /home/opc:

> jupyter.log contains details about jupyter
```
nohup jupyter notebook --ip=0.0.0.0 --port=8888  > ~/jupyter.log 2>&1 &
```
then cat jupyter.log to collect the token for the access

> mlflow.log contains details about mlflow
```
/home/opc/miniconda3/envs/myenv/bin/mlflow server --host 0.0.0.0 --port 5000 --artifacts-destination \$MLFLOW_ARTIFACT_URI > ~/mlflow.log 2>&1 &
```
then cat mlflow.log to review information in case you need to check further details about mlflow activity


- **Ubuntu:**
```
sudo iptables -L
sudo iptables -F
sudo iptables-save > /dev/null
```
If this does not work do also this:
```
sudo systemctl stop iptables
sudo systemctl disable iptables

sudo systemctl stop netfilter-persistent
sudo systemctl disable netfilter-persistent

sudo iptables -F
sudo iptables-save > /dev/null
```
!!! in case that you reboot the system you will need to manually start jupyter notebook and mlflow:
make sure check the following files from /home/ubuntu:

> jupyter.log contains details about jupyter
```
nohup jupyter notebook --ip=0.0.0.0 --port=8888 > ~jupyter.log 2>&1 &
```
then cat jupyter.log to collect the token for the access

> mlflow.log contains details about mlflow
```
nohup /home/ubuntu/miniconda3/envs/myenv/bin/mlflow server --host 0.0.0.0 --port 5000 --artifacts-destination $MLFLOW_ARTIFACT_URI > ~/mlflow.log 2>&1 &
```
then cat mlflow.log to review information in case you need to check further details about mlflow activity

## Notebook:
Both Ubuntu and Oracle Linux systems will create the notebook file mlflow_test_bucket.ipynb that contains the code to run experiments for mlflow. Once you allow access to Jupyter you will view the file in the list and you only need to double click on it and then a new tab will open its content.

You need to change in mlflow_test_bucket.ipynb the following line: mlflow.set_tracking_uri("http://:5000") to include the localhost if you are using mlflow in the same host with jupyter like we do in this scenario: mlflow.set_tracking_uri("http://localhost:5000")

## Storing Mlflow artifacts to OCI Bucket
Deployment depends on an [OCI Object Storage](https://docs.oracle.com/en-us/iaas/Content/Object/Concepts/objectstorageoverview.htm) Bucket to store the artifacts.
You can use an existing Bucket or let the automation create one for you.
To access the bucket, Mlflow uses [Customer Secret Key](https://docs.oracle.com/en-us/iaas/Content/Rover/IAM/User_Credentials/Secret_Keys/customer-secret-key_management.htm).
