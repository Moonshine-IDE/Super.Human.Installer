import winston from 'winston';
import 'winston-daily-rotate-file';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Define log format
const logFormat = winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
);

// Create rotating file transport
const fileTransport = new winston.transports.DailyRotateFile({
    filename: join(__dirname, 'logs', 'web-terminal-%DATE%.log'),
    datePattern: 'YYYY-MM-DD',
    maxSize: '20m',
    maxFiles: '14d',
    format: logFormat
});

// Create console transport for development
const consoleTransport = new winston.transports.Console({
    format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
    )
});

// Create logger
const logger = winston.createLogger({
    level: 'info',
    format: logFormat,
    transports: [
        fileTransport,
        consoleTransport
    ]
});

// Log format functions
const formatAuthLog = (ip, username, success) => ({
    event: 'authentication',
    ip,
    username,
    success,
    timestamp: new Date().toISOString()
});

const formatConnectionLog = (ip, type, status) => ({
    event: 'connection',
    ip,
    type, // 'http' or 'websocket'
    status,
    timestamp: new Date().toISOString()
});

const formatCommandLog = (ip, username, command) => ({
    event: 'command',
    ip,
    username,
    command,
    timestamp: new Date().toISOString()
});

export { 
    logger,
    formatAuthLog,
    formatConnectionLog,
    formatCommandLog
};
