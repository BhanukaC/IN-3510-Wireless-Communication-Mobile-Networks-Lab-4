// =============================
// App.js — Simple WebSocket Chat Client (React)
// =============================

import React, { useEffect, useRef, useState } from "react";

export default function App() {
  // ------------------------------
  // State variables
  // ------------------------------
  const [messages, setMessages] = useState([]); // stores received messages
  const [text, setText] = useState(""); // current input text
  const wsRef = useRef(null); // WebSocket reference (so it persists across renders)

  // ------------------------------
  // Connect to the WebSocket server
  // ------------------------------
  useEffect(() => {
    // Create a new WebSocket connection to your local server
    const ws = new WebSocket("ws://localhost:8080"); // must match your server port
    wsRef.current = ws;

    // When connected
    ws.onopen = () => console.log("✅ WS connected");

    // When disconnected
    ws.onclose = () => console.log("❌ WS disconnected");

    // Handle errors
    ws.onerror = (e) => console.error("⚠️ WS error:", e);

    // Handle incoming messages
    ws.onmessage = (evt) => {
      try {
        // Parse incoming JSON message
        const data = JSON.parse(evt.data);

        // Append message to chat list
        setMessages((prev) => [...prev, data]);
      } catch (e) {
        console.error("Parse error:", e);
      }
    };

    // Cleanup: close WS connection when component unmounts
    return () => ws.close();
  }, []);

  // ------------------------------
  // Send chat message to server
  // ------------------------------
  const sendChat = (e) => {
    e.preventDefault();

    // Construct a message object
    const msg = { type: "chat", message: text, device: "web" };

    // Send message only if WS connection is open
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(msg));
    }

    // Clear input after sending
    setText("");
  };

  // ------------------------------
  // Render UI
  // ------------------------------
  return (
    <div
      style={{
        maxWidth: 600,
        margin: "2rem auto",
        fontFamily: "sans-serif",
      }}
    >
      <h2>💬 WebSocket Chat</h2>

      {/* Display all messages */}
      <ul>
        {messages.map((m, i) => (
          <li key={i}>
            { m.type === "welcome"
              ? `👋 ${m.message}` // welcome message
              : m.type === "chat"
              ? `💬 ${m.message}` // chat message
              : JSON.stringify(m)}{" "}
            
          </li>
        ))}
      </ul>

      {/* Chat input form */}
      <form onSubmit={sendChat} style={{ display: "flex", gap: 8 }}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Type a message"
          style={{ flex: 1, padding: "0.5rem" }}
        />
        <button type="submit" style={{ padding: "0.5rem 1rem" }}>
          Send
        </button>
      </form>
    </div>
  );
}
