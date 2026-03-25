const express = require('express');
const { Server } = require('socket.io');
const http = require('http');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

io.on('connection', (socket) => {
    console.log(`[Socket.IO] New client connected: ${socket.id}`);

    // Standard event emission
    socket.emit('chat_message', { user: 'admin', text: 'Welcome to standard Node.js Socket.io!' });

    // Listen for client events
    socket.on('client_event', (data) => {
        console.log(`[Socket.IO] Received client_event:`, data);
        socket.emit('server_response', { status: 'ok', received: data });
    });

    // Handle acknowledgments safely
    socket.on('request_data', (args, callback) => {
        console.log(`[Socket.IO] Processed request_data with ACK requested`);
        if (typeof callback === 'function') {
            callback({ success: true, payload: "Ack processed" });
        }
    });

    socket.on('disconnect', () => {
        console.log(`[Socket.IO] Client disconnected: ${socket.id}`);
    });
});

// Lobby namespace
const lobbyNamespace = io.of('/lobby');
lobbyNamespace.on('connection', (socket) => {
    console.log(`[Socket.IO][/lobby] New client connected: ${socket.id}`);
    socket.emit('lobby_welcome', { message: 'You have entered the lobby namespace!' });

    socket.on('disconnect', () => {
        console.log(`[Socket.IO][/lobby] Client disconnected: ${socket.id}`);
    });
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`[Server] Standard Node.js Socket.io Server actively listening on port ${PORT}`);
});
