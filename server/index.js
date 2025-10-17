// server.js
const WebSocket = require("ws");

const wss = new WebSocket.Server({ port: 8080 });
console.log("✅ WebSocket server running on ws://localhost:8080");

// Helper function to broadcast messages to all clients
function broadcast(dataObj) {
  const payload = JSON.stringify(dataObj);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  });
}

// Handle client connections
wss.on("connection", (ws) => {
  console.log("📡 New client connected");

  // Send welcome message
  ws.send(
    JSON.stringify({
      type: "welcome",
      message: "Connected to WebSocket Server!",
    })
  );

  // Handle incoming client messages
  ws.on("message", (data) => {
    try {
      const msg = JSON.parse(data);
      console.log("📩 Received from client:", msg);
      if (msg.type === "chat") {
        if (msg.message === "time") {
          const now = new Date();
          broadcast({
            type: "chat",
            message: now.toLocaleString("sv-SE") + " from server", // e.g. "2025-10-17 21:34:12"
          });
        } else {
          broadcast({
            type: "chat",
            message: msg.device
              ? `${msg.message} (from ${msg.device})`
              : msg.message,
          });
        }
      }
    } catch (e) {
      console.error("❗ Error parsing message:", e.message);
    }
  });

  ws.on("close", () => console.log("❌ Client disconnected"));
  ws.on("error", (err) => console.error("⚠️ WebSocket error:", err.message));
});
