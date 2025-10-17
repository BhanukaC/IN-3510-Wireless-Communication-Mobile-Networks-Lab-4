// App.js
import React, { useEffect, useRef, useState } from "react";

export default function App() {
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState("");
  const wsRef = useRef(null);

  useEffect(() => {
    const ws = new WebSocket("ws://localhost:8080"); // matches your ws server
    wsRef.current = ws;

    ws.onopen = () => console.log("✅ WS connected");
    ws.onclose = () => console.log("❌ WS disconnected");
    ws.onerror = (e) => console.error("⚠️ WS error:", e);

    ws.onmessage = (evt) => {
      try {
        const data = JSON.parse(evt.data);
        setMessages((prev) => [...prev, data]);
      } catch (e) {
        console.error("Parse error:", e);
      }
    };

    return () => ws.close();
  }, []);

  const sendChat = (e) => {
    e.preventDefault();
    const msg = { type: "chat", message: text, device: "web" };
    wsRef.current?.readyState === WebSocket.OPEN &&
      wsRef.current.send(JSON.stringify(msg));
    setText("");
  };

  return (
    <div
      style={{ maxWidth: 600, margin: "2rem auto", fontFamily: "sans-serif" }}
    >
      <h2>WS Chat</h2>
      <ul>
        {messages.map((m, i) => (
          <li key={i}>
            {m.type === "clock"
              ? `🕒 ${m.iso}`
              : m.type === "welcome"
              ? `👋 ${m.message}`
              : m.type === "chat"
              ? `💬 ${m.message}`
              : JSON.stringify(m)}
          </li>
        ))}
      </ul>
      <form onSubmit={sendChat} style={{ display: "flex", gap: 8 }}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Type message"
        />
        <button type="submit">Send</button>
      </form>
    </div>
  );
}
