# Installation and setup instructions

# 1. Install script
sudo cp porkbun-ddns.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/porkbun-ddns.sh

# 2. Setup credentials (only method)
# TODO: This looks wrong
sudo mkdir -p /etc/porkbun
echo "your_api_key" | sudo tee /etc/porkbun/api-key
echo "your_api_secret" | sudo tee /etc/porkbun/api-secret
sudo chmod 600 /etc/porkbun/api-*

# 3. Install systemd files
# TODO: This should be a local systemd (user level)
#       need to verify the service and timer too
sudo cp porkbun-ddns@.service /etc/systemd/system/
sudo cp porkbun-ddns@.timer /etc/systemd/system/
sudo systemctl daemon-reload

# 4. Enable timer (runs every 30 minutes)
# TODO: What is this '@' syntax for parameters? should be in the
#       service file
sudo systemctl enable porkbun-ddns@"example.com:home:300".timer
sudo systemctl start porkbun-ddns@"example.com:home:300".timer
