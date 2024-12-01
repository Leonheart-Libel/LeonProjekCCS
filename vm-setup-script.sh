#!/bin/bash

# Update and install dependencies
apt-get update
apt-get upgrade -y
apt-get install -y nginx cifs-utils ufw

# Create a simple HTML file with the welcome message
cat << 'EOT' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Web Server</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            display: flex; 
            justify-content: center; 
            align-items: center; 
            height: 100vh; 
            margin: 0; 
            background-color: #f0f0f0; 
        }
        .message { 
            font-size: 24px; 
            text-align: center; 
            padding: 20px; 
            background-color: white; 
            border-radius: 10px; 
            box-shadow: 0 4px 6px rgba(0,0,0,0.1); 
        }
        .file-status {
            margin-top: 20px;
            font-size: 16px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="message">
        Welcome to Web Server ${SERVER_NUMBER} ${REGION} Region
        <div class="file-status" id="file-status">
            File Share Status: Checking...
        </div>
    </div>
    <script>
        fetch('/file-status.txt')
            .then(response => {
                if (response.ok) {
                    document.getElementById('file-status').innerHTML = 'File Share Status: Connected ✓';
                    document.getElementById('file-status').style.color = 'green';
                } else {
                    document.getElementById('file-status').innerHTML = 'File Share Status: Not Connected ✗';
                    document.getElementById('file-status').style.color = 'red';
                }
            })
            .catch(() => {
                document.getElementById('file-status').innerHTML = 'File Share Status: Not Connected ✗';
                document.getElementById('file-status').style.color = 'red';
            });
    </script>
</body>
</html>
EOT

# Mount File Share
mkdir -p /mnt/webapp-share
mount -t cifs //${STORAGE_ACCOUNT_NAME}.file.core.windows.net/${FILE_SHARE_NAME} /mnt/webapp-share \
  -o vers=3.0,username=${STORAGE_ACCOUNT_NAME},password=${STORAGE_ACCOUNT_KEY},dir_mode=0777,file_mode=0777,serverino

# Verify file share mount
if mountpoint -q /mnt/webapp-share; then
    echo "File share mounted successfully"
    
    # Create a verification file in the mounted share
    echo "File share connected successfully for ${REGION} Region - Server ${SERVER_NUMBER}" > /mnt/webapp-share/file-status.txt
    
    # Copy the verification file to nginx web root for frontend verification
    cp /mnt/webapp-share/file-status.txt /var/www/html/file-status.txt
else
    echo "File share mount failed"
fi

# Persist mount in fstab
echo "//${STORAGE_ACCOUNT_NAME}.file.core.windows.net/${FILE_SHARE_NAME} /mnt/webapp-share cifs nofail,vers=3.0,username=${STORAGE_ACCOUNT_NAME},password=${STORAGE_ACCOUNT_KEY},dir_mode=0777,file_mode=0777,serverino 0 0" >> /etc/fstab

# Configure nginx to use the custom HTML
cat << 'EOT' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOT

ufw allow 80/tcp
ufw enable

# Restart nginx to apply changes
systemctl restart nginx

# Additional verification logging
echo "File share verification completed for ${REGION} Region - Server ${SERVER_NUMBER}" >> /var/log/file-share-mount.log

