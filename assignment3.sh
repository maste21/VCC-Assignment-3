#!/bin/bash

# Settings
ZONE_GCP="us-central1-a"
DATA_PATH_LOCAL="$HOME/local/data"  
DATA_PATH_REMOTE="$HOME" 
USER_GCP="vboxuser"  
THRESHOLD_CPU=75
DIR_APP="myapp"
APP_PORT="8080"

# Authenticate to Google Cloud
gcloud auth activate-service-account --key-file=vcc-assignment-452211-869fe97485ac.json
gcloud config set project vcc-assignment-452211

# Fetch CPU Utilization
USAGE_CPU=$(top -bn 1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
echo "Current CPU Usage: $USAGE_CPU%"

# Verify if the instance exists on Google Cloud
INSTANCE_ACTIVE=$(gcloud compute instance-groups managed list-instances autoscale-vm-group --zone us-central1-a --format="value(name)" | head -n 1)

# Provision a new VM if CPU load surpasses the limit and no instance exists
if (( $(echo "$USAGE_CPU > $THRESHOLD_CPU" | bc -l) )); then
    if [ -z "$INSTANCE_ACTIVE" ]; then
        echo "CPU usage is now above $THRESHOLD_CPU%. Initiating a new VM on Google Cloud..."

        gcloud compute instance-templates create auto-vm-template \
        --image-family ubuntu-2204-lts \
        --image-project ubuntu-os-cloud \
        --machine-type e2-medium \
        --boot-disk-size 10GB \
        --tags http-server,https-server

        gcloud compute instance-groups managed create autoscale-vm-group \
        --base-instance-name autoscale-vm \
        --template auto-vm-template \
        --size 1 \
        --zone us-central1-a

        gcloud compute instance-groups managed set-autoscaling autoscale-vm-group \
        --max-num-replicas 5 \
        --min-num-replicas 1 \
        --target-cpu-utilization 0.75 \
        --cool-down-period 60 \
        --zone us-central1-a
        
        INSTANCE_VM=$(gcloud compute instance-groups managed list-instances autoscale-vm-group --zone us-central1-a --format="value(name)" | head -n 1)
        
        echo "Allowing time for the VM to initialize..."
        sleep 30
        
    echo "Uploading files to the Google Cloud VM..."
        gcloud compute scp --recurse "$DATA_PATH_LOCAL" "$USER_GCP@$INSTANCE_VM:$DATA_PATH_REMOTE" --zone="$ZONE_GCP"
            
        # Step 6: Deploy the Example Node.js App
    echo "Setting up the Node.js application on the VM..."
        
        # SSH into the VM and execute commands
        gcloud compute ssh $INSTANCE_VM --zone $ZONE_GCP --command "
          
          # Update packages and install prerequisites
          sudo apt update
          sudo apt install -y nodejs npm nginx
          
          # Prepare application directory and install dependencies
          mkdir /home/$USER/$DIR_APP
          cd /home/$USER/$DIR_APP
          npm init -y
          npm install express
          
          # Add application code
          echo \"const express = require('express'); const app = express(); const port = $APP_PORT; app.get('/', (req, res) => { res.send('Hello, world! Here is a demo app running on $INSTANCE_VM.'); }); app.listen(port, () => { console.log('Server listening on port ' + port); });\" > app.js
          
          # Start the app in the background
          nohup node app.js &
          
          # Configure nginx for proxying
          sudo rm /etc/nginx/sites-enabled/default
          echo 'server {
            listen 80;
            server_name _;
            location / {
            proxy_pass http://localhost:$APP_PORT;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
            }
          }' | sudo tee /etc/nginx/sites-available/default
          
          # Restart nginx
          sudo systemctl restart nginx
        "
        
    echo "The demo application is now active on $INSTANCE_VM."
        
        # Step 7: Simulate a Load for Auto-Scaling
    echo "Running a CPU load test to validate auto-scaling..."
        gcloud compute ssh $INSTANCE_VM --zone $ZONE_GCP --command "
          sudo apt install -y apache2-utils
          ab -n 1000 -c 100 http://localhost:$APP_PORT/
        "
        
    echo "CPU load test and auto-scaling process completed."
        
    echo "Script execution finished!"
            
        else
            echo "Google Cloud VM instance detected. Skipping VM creation."
        fi

# Shut down the VM if CPU usage drops below the defined limit
elif (( $(echo "$USAGE_CPU < $THRESHOLD_CPU" | bc -l) )); then
    if [ -n "$INSTANCE_ACTIVE" ]; then
        echo "CPU usage is below $THRESHOLD_CPU%. Decommissioning the existing GCP VM..."
        gcloud compute instance-groups managed delete autoscale-vm-group --zone us-central1-a 
    else
        echo "No running GCP VM instances found to terminate."
    fi
fi
