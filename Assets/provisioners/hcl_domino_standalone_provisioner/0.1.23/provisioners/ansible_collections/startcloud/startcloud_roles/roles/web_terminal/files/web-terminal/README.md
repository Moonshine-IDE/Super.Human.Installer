# Secure Web Terminal

A secure web-based terminal interface that provides shell access through a browser, featuring HTTPS/SSL encryption and multi-layer authentication.

## Security Features

- **HTTPS/SSL Encryption**: All traffic is encrypted using SSL certificates
- **Multi-layer Authentication**:
  - HTTP Basic Authentication for web access
  - WebSocket authentication for terminal connections
  - Both layers use the same credentials from config.yaml
- **Configurable Users**: Multiple users can be defined in the config.yaml file
- **Secure by Default**: Requires HTTPS and authentication to function

## Installation

1. Clone or copy the files to your target location:
```bash
sudo mkdir /opt/web-terminal
sudo cp -r * /opt/web-terminal/
cd /opt/web-terminal
```

2. Install dependencies:
```bash
sudo npm install
```

3. Configure the application:
   - Copy the example config:
     ```bash
     sudo cp config.yaml.example config.yaml
     ```
   - Edit config.yaml to set:
     - SSL certificate paths
     - Server port
     - User credentials
     - Terminal preferences

4. Set up SSL certificates:
   - If using Let's Encrypt:
     ```bash
     sudo certbot certonly --standalone -d your-domain.com
     ```
   - Update config.yaml with your certificate paths:
     ```yaml
     server:
       ssl:
         cert: /etc/letsencrypt/live/your-domain.com/fullchain.pem
         key: /etc/letsencrypt/live/your-domain.com/privkey.pem
     ```

5. Install the systemd service:
```bash
sudo cp web-terminal.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable web-terminal
sudo systemctl start web-terminal
```

## Configuration (config.yaml)

```yaml
server:
  port: 3000
  ssl:
    cert: /path/to/cert.pem
    key: /path/to/key.pem

users:
  admin: your_secure_password
  user1: another_password

terminal:
  shell: bash
  cols: 80
  rows: 30
```

## Usage

1. Access the terminal through your browser:
```
https://your-domain.com:3000
```

2. Enter your credentials when prompted (configured in config.yaml)

3. You will now have access to a secure terminal session

## Security Notes

- Always use strong passwords in config.yaml
- Keep config.yaml secure with appropriate file permissions:
  ```bash
  sudo chown root:root config.yaml
  sudo chmod 600 config.yaml
  ```
- Regularly update SSL certificates
- Monitor logs for unauthorized access attempts:
  ```bash
  sudo journalctl -u web-terminal
  ```

## Troubleshooting

### Double Authentication Prompt
The system uses two layers of authentication for enhanced security:
1. HTTP Basic Auth for initial web access
2. WebSocket authentication for terminal connection

Both use the same credentials, so you can enter the same username/password for both prompts.

### Common Issues

1. SSL Certificate Problems:
   ```bash
   sudo systemctl status web-terminal
   ```
   Check if the SSL paths in config.yaml are correct

2. Permission Issues:
   ```bash
   sudo chown -R root:root /opt/web-terminal
   sudo chmod -R 755 /opt/web-terminal
   sudo chmod 600 /opt/web-terminal/config.yaml
   ```

3. Port Already in Use:
   ```bash
   sudo netstat -tulpn | grep <port>
   ```
   Change the port in config.yaml if needed

## Logs

The application maintains detailed logs of all connections, authentication attempts, and commands:

1. System Service Logs:
```bash
sudo journalctl -u web-terminal -f
```

2. Application Logs:
- Location: `/opt/web-terminal/logs/web-terminal-YYYY-MM-DD.log`
- Rotated daily with 14-day retention
- JSON formatted logs include:
  * IP addresses of connections
  * Authentication attempts (success/failure)
  * WebSocket connections/disconnections
  * Commands executed
  
View latest application logs:
```bash
tail -f /opt/web-terminal/logs/web-terminal-$(date +%Y-%m-%d).log
```

Log Format:
```json
{
  "event": "authentication|connection|command",
  "ip": "client_ip_address",
  "username": "user_who_connected",
  "timestamp": "ISO-8601 timestamp",
  "success": true|false,  // for authentication events
  "command": "executed_command",  // for command events
  "type": "http|websocket",  // for connection events
  "status": "connected|disconnected"  // for connection events
}
```

## Updates

To update the application:
1. Stop the service:
   ```bash
   sudo systemctl stop web-terminal
   ```
2. Update files
3. Restart the service:
   ```bash
   sudo systemctl restart web-terminal
