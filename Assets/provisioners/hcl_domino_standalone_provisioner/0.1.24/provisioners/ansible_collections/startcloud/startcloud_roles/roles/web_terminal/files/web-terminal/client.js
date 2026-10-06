const term = new Terminal({
    cursorBlink: true,
    theme: {
        background: '#1e1e1e',
        foreground: '#ffffff'
    }
});

const fitAddon = new FitAddon.FitAddon();
term.loadAddon(fitAddon);

// Initialize terminal
term.open(document.getElementById('terminal-container'));
fitAddon.fit();

// Handle terminal resizing
window.addEventListener('resize', () => {
    fitAddon.fit();
});

// Get stored credentials or prompt user
let username = localStorage.getItem('terminal_username') || prompt('Username:');
let password = localStorage.getItem('terminal_password') || prompt('Password:');

// Store credentials
localStorage.setItem('terminal_username', username);
localStorage.setItem('terminal_password', password);

// Create authentication header
const auth = btoa(`${username}:${password}`);

// Connect to WebSocket server with authentication
const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
const ws = new WebSocket(`${protocol}//${window.location.host}`, [], {
    headers: {
        'Authorization': `Basic ${auth}`
    }
});

// Handle incoming data from server
ws.onmessage = (event) => {
    term.write(event.data);
};

// Send terminal input to server
term.onData(data => {
    ws.send(data);
});

// Handle connection open
ws.onopen = () => {
    term.write('\x1b[32mConnected to terminal.\x1b[0m\r\n');
};

// Handle connection close
ws.onclose = () => {
    term.write('\x1b[31mDisconnected from terminal.\x1b[0m\r\n');
};

// Handle connection error
ws.onerror = (error) => {
    console.error('WebSocket error:', error);
    term.write('\x1b[31mError: Failed to connect to terminal. Please check your credentials.\x1b[0m\r\n');
    // Clear stored credentials on error
    localStorage.removeItem('terminal_username');
    localStorage.removeItem('terminal_password');
    // Reload page to prompt for credentials again
    setTimeout(() => window.location.reload(), 2000);
};
