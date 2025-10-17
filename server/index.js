// =============================
// index.js — Simple WebSocket Server
// =============================

// Import the 'ws' library for WebSocket functionality
const WebSocket = require("ws");

// Create a new WebSocket server instance listening on port 8080
const wss = new WebSocket.Server({ port: 8080 });
console.log("✅ WebSocket server running on ws://localhost:8080");

// ----------------------------------------------------
// Helper function: broadcast()
// Sends a JSON message to all connected clients
// ----------------------------------------------------
function broadcast(dataObj) {
  const payload = JSON.stringify(dataObj); // Convert object → JSON string
  wss.clients.forEach((client) => {
    // Check if the client connection is still open
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload); // Send the message
    }
  });
}

// ----------------------------------------------------
// Handle new client connections
// ----------------------------------------------------
wss.on("connection", (ws) => {
  console.log("📡 New client connected");

  // Send a welcome message to the newly connected client
  ws.send(
    JSON.stringify({
      type: "welcome",
      message: "Connected to WebSocket Server!",
    })
  );

  // -----------------------------------------------
  // Handle messages received from this client
  // -----------------------------------------------
  ws.on("message", (data) => {
    try {
      // Parse the incoming message (JSON string → object)
      const msg = JSON.parse(data);
      console.log("📩 Received from client:", msg);

      // If the message type is 'chat', process it
      if (msg.type === "chat") {
        // If the message text is "time", respond with the server time
        if (msg.message === "time") {
          const now = new Date();
          broadcast({
            type: "chat",
            // Format date/time in Swedish locale (sv-SE)
            message: now.toLocaleString("sv-SE") + " from server",
          });
        } else {
          // Otherwise, just echo the message to all clients
          broadcast({
            type: "chat",
            message: msg.device
              ? `${msg.message} (from ${msg.device})`
              : msg.message,
          });
        }
      }
    } catch (e) {
      // If JSON parsing fails, log the error
      console.error("❗ Error parsing message:", e.message);
    }
  });

  // Log when the client disconnects
  ws.on("close", () => console.log("❌ Client disconnected"));

  // Handle WebSocket connection errors
  ws.on("error", (err) => console.error("⚠️ WebSocket error:", err.message));
});
