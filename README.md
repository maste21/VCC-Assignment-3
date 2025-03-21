# VCC-Assignment-3
Execute the below commands on the local VM to install the Google Cloud SDK:

  Install prerequisites
  
    sudo apt install apt-transport-https ca-certificates gnupg curl -y

 Add Google Cloud public key

    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

 Add the Cloud SDK distribution URI  
 
     echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
     http://packages.cloud.google.com/apt cloud-sdk main" | \
     sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

 Update package lists and install Google Cloud SDK
 
     sudo apt update && sudo apt install google-cloud-cli -y

 Verify installation
    gcloud --version

# The below command to install Stress package
sudo apt install -y stress
