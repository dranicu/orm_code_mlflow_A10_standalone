#!/bin/bash

#cloudinit execution
echo "running cloudinit.sh script"

region=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/regionInfo/regionIdentifier`
obj_storage_namespace=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/obj_storage_namespace`
bucket_name=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/bucket_name`
customer_access_key=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/customer_access_key`
customer_secret_key=`curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/customer_secret_key`
MLFLOW_S3_ENDPOINT_URL="https://${obj_storage_namespace}.compat.objectstorage.${region}.oraclecloud.com"
MLFLOW_ARTIFACT_URI="s3://${bucket_name}"
image_name="mlflow:latest"

echo "export REGION=\"$region\"" >> /home/opc/.bashrc
echo "export OBJ_STORAGE_NAMESPACE=\"$obj_storage_namespace\"" >> /home/opc/.bashrc
echo "export BUCKET_NAME=\"$bucket_name\"" >> /home/opc/.bashrc
echo "export AWS_ACCESS_KEY_ID=\"$customer_access_key\"" >> /home/opc/.bashrc
echo "export AWS_SECRET_ACCESS_KEY=\"$customer_secret_key\"" >> /home/opc/.bashrc
echo "export MLFLOW_S3_ENDPOINT_URL=\"$MLFLOW_S3_ENDPOINT_URL\"" >> /home/opc/.bashrc
echo "export MLFLOW_ARTIFACT_URI=\"$MLFLOW_ARTIFACT_URI\"" >> /home/opc/.bashrc
echo "export image_name=\"$image_name\"" >> /home/opc/.bashrc 

echo '[default]' > /home/opc/credentials
echo "aws_access_key_id=$customer_access_key" >> /home/opc/credentials
echo "aws_secret_access_key=$customer_secret_key" >> /home/opc/credentials
echo "region=$region" >> /home/opc/credentials
echo "endpoint_url=$MLFLOW_S3_ENDPOINT_URL" >> /home/opc/credentials
chown opc:opc /home/opc/credentials

dnf install -y dnf-utils zip unzip gcc
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf remove -y runc

echo "INSTALL DOCKER"
dnf install -y docker-ce --nobest

echo "ENABLE DOCKER"
systemctl enable docker.service

echo "INSTALL NVIDIA CONT TOOLKIT"
dnf install -y nvidia-container-toolkit

echo "START DOCKER"
systemctl start docker.service

echo "PYTHON packages"
python3 -m pip install --upgrade pip wheel oci
python3 -m pip install --upgrade setuptools
python3 -m pip install oci-cli
python3 -m pip install langchain
python3 -m pip install python-multipart
python3 -m pip install pypdf
python3 -m pip install six

echo "GROWFS"
/usr/libexec/oci-growfs -y


echo "Export nvcc"
sudo -u opc bash -c 'echo "export PATH=\$PATH:/usr/local/cuda/bin" >> /home/opc/.bashrc'
sudo -u opc bash -c 'echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/cuda/lib64" >> /home/opc/.bashrc'

echo "Add docker opc"
usermod -aG docker opc

echo "CUDA toolkit"
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
dnf clean all
dnf -y install cuda-toolkit-12-4
dnf -y install cudnn

echo "Python 3.10.6"
dnf install curl gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make sqlite-devel -y
wget https://www.python.org/ftp/python/3.10.6/Python-3.10.6.tar.xz
tar -xf Python-3.10.6.tar.xz
cd Python-3.10.6/
./configure --enable-optimizations --with-openssl=/usr/include/openssl
make -j $(nproc)
sudo make altinstall
python3.10 -V
cd ..
rm -rf Python-3.10.6*

echo "Git"
dnf install -y git

echo "Conda install"
mkdir -p /home/opc/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /home/opc/miniconda3/miniconda.sh
bash /home/opc/miniconda3/miniconda.sh -b -u -p /home/opc/miniconda3
rm -rf /home/opc/miniconda3/miniconda.sh
/home/opc/miniconda3/bin/conda init bash
chown -R opc:opc /home/opc/miniconda3
su - opc -c "/home/opc/miniconda3/bin/conda init bash"
export /home/opc/miniconda3/bin/conda >> /home/opc/.bashrc

su - opc -c "source /home/opc/.bashrc && \
mkdir -p ~/.aws && \
mv /home/opc/credentials ~/.aws"

echo "Creating Conda environment"
su - opc -c "source /home/opc/.bashrc && /home/opc/miniconda3/bin/conda create -n myenv python=3.10 -y"

echo "Activating Conda environment" 
su - opc -c "/home/opc/miniconda3/bin/conda init bash && \
  source /home/opc/.bashrc && \
  conda activate myenv && \
  conda install jupyter boto3 scikit-learn=1.5.1 -y && \
  pip install mlflow ipykernel && \
  python -m ipykernel install --user --name=myenv --display-name='Python (myenv)'
  "

su - opc -c "source /home/opc/miniconda3/etc/profile.d/conda.sh && \
  conda activate myenv && \
  nohup bash -c 'source ~/.bashrc && source ~/miniconda3/etc/profile.d/conda.sh && conda activate myenv && jupyter notebook --ip=0.0.0.0 --port=8888 > ~/jupyter.log 2>&1 & \
  nohup /home/opc/miniconda3/envs/myenv/bin/mlflow server --host 0.0.0.0 --port 5000 --artifacts-destination $MLFLOW_ARTIFACT_URI > ~/mlflow.log 2>&1 &
  echo "conda activate myenv" >> /home/opc/.bashrc
  "


echo "Preparing notebook to test mlflow access to bucket"
su - opc -c "cat <<EOF > /home/opc/mlflow_test_bucket.ipynb
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

date