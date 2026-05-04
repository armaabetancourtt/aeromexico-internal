const winston = require('winston');
const fs = require('fs');

const logsDir = '/app/logs';
if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, { recursive: true });

const fmt = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message }) => `[${timestamp}] ${level.toUpperCase()}: ${message}`)
);

const logger = winston.createLogger({
  level: 'info',
  format: fmt,
  transports: [
    new winston.transports.Console({ format: winston.format.combine(winston.format.colorize(), fmt) }),
    new winston.transports.File({ filename: '/app/logs/admin.log', maxsize: 5242880, maxFiles: 5 })
  ]
});

module.exports = logger;
