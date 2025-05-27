import express from 'express';
import { WebSocketServer } from 'ws';
import { spawn } from 'node-pty';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import os from 'os';
import https from 'https';
import fs from 'fs/promises';
import basicAuth from 'express-basic-auth';
import yaml from 'js-yaml';
import { logger, formatAuthLog, formatConnectionLog, formatCommandLog } from './logger.js';

// Ensure logs directory exists
try {
    await fs.mkdir(join(__dirname, 'logs')).catch(() => {});
} catch (error) {
    console.error('Error creating logs directory:', error);
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load configuration
let config;
try {
    config = yaml.load(await fs.readFile(join(__dirname, 'config.yaml'), 'utf8'));
} catch (error) {
    console.error('Error loading config.yaml:', error);
    process.exit(1);
}

const app = express();
const port = config.server.port;

// Basic authentication middleware
app.use((req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress;
    const auth = basicAuth({
        users: config.users,
        challenge: true,
        realm: 'Web Terminal',
        authorizer: (username, password) => {
            const authorized = config.users[username] === password;
            logger.info(formatAuthLog(ip, username, authorized));
            return authorized;
        }
    });
    auth(req, res, next);
});

// Log all requests
app.use((req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress;
    logger.info(formatConnectionLog(ip, 'http', 'connected'));
    next();
});

// Add security headers
app.use((req, res, next) => {
    res.setHeader('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    next();
});

// Serve static files
app.use(express.static(__dirname));

// Serve robots.txt
app.get('/robots.txt', (req, res) => {
    res.type('text/plain');
    res.send('User-agent: *\nDisallow: /\nX-Robots-Tag: noindex, nofollow, noarchive, nosnippet');
});

// WebSocket connection handler
function setupWebSocketServer(server) {
    const wss = new WebSocketServer({ 
        server,
        verifyClient: (info, cb) => {
            const auth = info.req.headers.authorization;
            if (!auth) {
                cb(false, 401, 'Unauthorized');
                return;
            }
            
            const [username, password] = Buffer.from(auth.split(' ')[1], 'base64')
                .toString()
                .split(':');
                
            if (config.users[username] === password) {
                cb(true);
            } else {
                cb(false, 401, 'Unauthorized');
            }
        }
    });

    wss.on('connection', (ws, req) => {
        const ip = req.socket.remoteAddress;
        const auth = req.headers.authorization || '';
        const [username] = Buffer.from(auth.split(' ')[1] || '', 'base64')
            .toString()
            .split(':');
            
        logger.info(formatConnectionLog(ip, 'websocket', 'connected'));

        // Spawn terminal
        const shell = os.platform() === 'win32' ? 'powershell.exe' : config.terminal.shell;
        const pty = spawn(shell, [], {
            name: 'xterm-color',
            cols: config.terminal.cols,
            rows: config.terminal.rows,
            cwd: process.env.HOME,
            env: process.env
        });

        // Handle incoming data from client
        ws.on('message', (data) => {
            const command = data.toString();
            logger.info(formatCommandLog(ip, username, command));
            pty.write(data);
        });

        // Send terminal output to client
        pty.on('data', (data) => {
            try {
                ws.send(data);
            } catch (ex) {
                // Client probably disconnected
            }
        });

        // Clean up on close
        ws.on('close', () => {
            pty.kill();
            logger.info(formatConnectionLog(ip, 'websocket', 'disconnected'));
        });
    });
}

// Start server
async function startServer() {
    try {
        // SSL configuration
        const sslOptions = {
            cert: await fs.readFile(config.server.ssl.cert),
            key: await fs.readFile(config.server.ssl.key)
        };

        // Create HTTPS server
        const server = https.createServer(sslOptions, app);
        server.listen(port, () => {
            console.log(`HTTPS Server running at https://localhost:${port}`);
        });

        // Setup WebSocket server
        setupWebSocketServer(server);
    } catch (error) {
        console.error('Failed to start HTTPS server:', error);
        process.exit(1);
    }
}

startServer();
