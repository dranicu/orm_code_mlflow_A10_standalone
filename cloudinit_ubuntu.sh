#!/bin/bash

# AI_financial_test
echo "running cloudinit.sh script"

region=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/regionInfo/regionIdentifier`
obj_storage_namespace=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/obj_storage_namespace`
bucket_name=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/bucket_name`
customer_access_key=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/customer_access_key`
customer_secret_key=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/customer_secret_key`
MLFLOW_S3_ENDPOINT_URL="https://${obj_storage_namespace}.compat.objectstorage.${region}.oraclecloud.com"
MLFLOW_ARTIFACT_URI="s3://${bucket_name}"
image_name="mlflow:latest"

echo "export REGION=\"$region\"" >> /home/ubuntu/.bashrc
echo "export OBJ_STORAGE_NAMESPACE=\"$obj_storage_namespace\"" >> /home/ubuntu/.bashrc
echo "export BUCKET_NAME=\"$bucket_name\"" >> /home/ubuntu/.bashrc
echo "export AWS_ACCESS_KEY_ID=\"$customer_access_key\"" >> /home/ubuntu/.bashrc
echo "export AWS_SECRET_ACCESS_KEY=\"$customer_secret_key\"" >> /home/ubuntu/.bashrc
echo "export MLFLOW_S3_ENDPOINT_URL=\"$MLFLOW_S3_ENDPOINT_URL\"" >> /home/ubuntu/.bashrc
echo "export MLFLOW_ARTIFACT_URI=\"$MLFLOW_ARTIFACT_URI\"" >> /home/ubuntu/.bashrc
echo "export image_name=\"$image_name\"" >> /home/ubuntu/.bashrc
echo "export public_ip=\"$public_ip\"" >> /home/ubuntu/.bashrc

echo '[default]' > /home/ubuntu/credentials
echo "aws_access_key_id=$customer_access_key" >> /home/ubuntu/credentials
echo "aws_secret_access_key=$customer_secret_key" >> /home/ubuntu/credentials
echo "region=$region" >> /home/ubuntu/credentials
echo "endpoint_url=$MLFLOW_S3_ENDPOINT_URL" >> /home/ubuntu/credentials
chown ubuntu:ubuntu /home/ubuntu/credentials

apt-get update -y
apt-get install -y dnf-utils zip unzip gcc curl openssl libssl-dev libbz2-dev libffi-dev zlib1g-dev wget make git

echo "INSTALL NVIDIA CUDA + TOOLKIT + drivers"
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update -y
apt-get -y install cuda-toolkit-12-5
apt-get install -y nvidia-driver-555
apt-get -y install cudnn
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit

# Add Docker repository and install Docker
apt-get remove -y runc
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

echo "ENABLE DOCKER"
systemctl enable docker.service

echo "START DOCKER"
systemctl start docker.service


echo "PYTHON packages"
apt-get install -y python3-pip
python3 -m pip install --upgrade pip wheel oci
python3 -m pip install --upgrade setuptools
python3 -m pip install oci-cli langchain python-multipart pypdf six

echo "GROWFS"
growpart /dev/sda 1
resize2fs /dev/sda1

echo "Export nvcc"
echo "export PATH=\$PATH:/usr/local/cuda/bin" >> /home/ubuntu/.bashrc
echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/cuda/lib64" >> /home/ubuntu/.bashrc

echo "Add docker ubuntu"
usermod -aG docker ubuntu

echo "Python 3.10.6"
wget https://www.python.org/ftp/python/3.10.6/Python-3.10.6.tar.xz
tar -xf Python-3.10.6.tar.xz
cd Python-3.10.6/
./configure --enable-optimizations --with-openssl=/usr/include/openssl
make -j $(nproc)
make altinstall
python3.10 -V
cd ..
rm -rf Python-3.10.6*

apt install -y python3-venv

echo "Git"
apt-get install -y git

echo "Conda"
mkdir -p /home/ubuntu/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /home/ubuntu/miniconda3/miniconda.sh
bash /home/ubuntu/miniconda3/miniconda.sh -b -u -p /home/ubuntu/miniconda3
rm -rf /home/ubuntu/miniconda3/miniconda.sh
/home/ubuntu/miniconda3/bin/conda init bash
chown -R ubuntu:ubuntu /home/ubuntu/miniconda3
chown ubuntu:ubuntu /home/ubuntu/.bashrc
# export /home/ubuntu/miniconda3/bin/conda >> /home/ubuntu/.bashrc
echo 'export PATH="/home/ubuntu/miniconda3/bin:$PATH"' >> /home/ubuntu/.bashrc

su - ubuntu -c "source /home/ubuntu/.bashrc && \
mkdir -p ~/.aws && \
mv /home/ubuntu/credentials ~/.aws"


echo "Creating Conda environment" 
su - ubuntu -c "source /home/ubuntu/.bashrc && /home/ubuntu/miniconda3/bin/conda create -n myenv python=3.10 -y"

echo "Activating Conda environment" 
su - ubuntu -c "
  source /home/ubuntu/miniconda3/etc/profile.d/conda.sh; \
  conda activate myenv; \
  conda install jupyter boto3 scikit-learn=1.5.1 -y; \
  pip install mlflow ipykernel; \
  python -m ipykernel install --user --name=myenv --display-name='Python (myenv)'; \
  nohup bash -c 'source ~/.bashrc && jupyter notebook --ip=0.0.0.0 --port=8888 > ~/jupyter.log 2>&1 & \
  nohup /home/ubuntu/miniconda3/envs/myenv/bin/mlflow server --host 0.0.0.0 --port 5000 --artifacts-destination $MLFLOW_ARTIFACT_URI > ~/mlflow.log 2>&1 &
  echo "conda activate myenv" >> /home/ubuntu/.bashrc
"

echo "Preparing notebook to test mlflow access to bucket"
su - ubuntu -c "cat <<EOF > /home/ubuntu/mlflow_test_bucket.ipynb
{
 \"cells\": [
  {
   \"cell_type\": \"code\",
   \"execution_count\": null,
   \"metadata\": {},
   \"outputs\": [],
   \"source\": [
    \"import mlflow\\n\",
    \"import os\\n\",
    \"from sklearn.model_selection import train_test_split\\n\",
    \"from sklearn.datasets import load_diabetes\\n\",
    \"from sklearn.ensemble import RandomForestRegressor\\n\",
    \"\\n\",
    \"# Ignoring the TLS\\n\",
    \"os.environ[\\\"MLFLOW_TRACKING_INSECURE_TLS\\\"] = \\\"true\\\"\\n\",
    \"# Set the Mlflow tracking Url.\\n\",
    \"mlflow.set_tracking_uri(\\\"http://$public_ip:5000\\\")\\n\",
    \"# Setting experiment id\\n\",
    \"mlflow.set_experiment(experiment_id=\\\"0\\\")\\n\",
    \"\\n\",
    \"mlflow.autolog()\\n\",
    \"db = load_diabetes()\\n\",
    \"\\n\",
    \"X_train, X_test, y_train, y_test = train_test_split(db.data, db.target)\\n\",
    \"\\n\",
    \"# Create and train models.\\n\",
    \"rf = RandomForestRegressor(n_estimators=100, max_depth=6, max_features=3)\\n\",
    \"rf.fit(X_train, y_train)\\n\",
    \"\\n\",
    \"# Use the model to make predictions on the test dataset.\\n\",
    \"predictions = rf.predict(X_test)\\n\",
    \"print(predictions)\\n\"
   ]
  }
 ],
 \"metadata\": {
  \"kernelspec\": {
   \"display_name\": \"Python 3\",
   \"language\": \"python\",
   \"name\": \"python3\"
  },
  \"language_info\": {
   \"codemirror_mode\": {
    \"name\": \"ipython\",
    \"version\": 3
   },
   \"file_extension\": \".py\",
   \"mimetype\": \"text/x-python\",
   \"name\": \"python\",
   \"nbconvert_exporter\": \"python\",
   \"pygments_lexer\": \"ipython3\",
   \"version\": \"3.8.5\"
  }
 },
 \"nbformat\": 4,
 \"nbformat_minor\": 4
}
EOF"

su - ubuntu -c "sudo nvidia-smi"
date