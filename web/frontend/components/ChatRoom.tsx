"use client";

import { useEffect, useRef, useState } from "react";

// ---------------------------------------------------------------------------
// Config — adjust to match your FastAPI host
// ---------------------------------------------------------------------------
const WS_BASE = process.env.NEXT_PUBLIC_WS_BASE ?? (process.env.NEXT_PUBLIC_API_URL ? process.env.NEXT_PUBLIC_API_URL.replace("http", "ws") : "ws://localhost:8000");

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface Message {
  id: number;
  raw: string; // stored unsanitised
}

// ---------------------------------------------------------------------------
// Main chat room component
// ---------------------------------------------------------------------------
export default function ChatRoom({ roomId = "general" }: { roomId?: string }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [status, setStatus] = useState<"connecting" | "open" | "closed">("connecting");
  const wsRef = useRef<WebSocket | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const msgId = useRef(0);

  useEffect(() => {
    const ws = new WebSocket(`${WS_BASE}/ws/chat/${roomId}`);
    wsRef.current = ws;

    ws.onopen = () => setStatus("open");
    ws.onclose = () => setStatus("closed");

    ws.onmessage = (event) => {
      const raw: string = event.data;
      setMessages((prev) => [...prev, { id: msgId.current++, raw }]);
    };

    return () => ws.close();
  }, [roomId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const sendMessage = () => {
    if (!input.trim() || wsRef.current?.readyState !== WebSocket.OPEN) return;
    wsRef.current.send(input);
    setInput("");
  };

  return (
    <div style={styles.wrapper}>
      <header style={styles.header}>
        <span style={styles.title}>💬 #{roomId}</span>
        <span style={{ ...styles.badge, background: statusColor(status) }}>
          {status}
        </span>
      </header>

      {/* Message list */}
      <div style={styles.messages}>
        {messages.map((m) => (
          <div key={m.id} style={styles.bubble}>
            <span dangerouslySetInnerHTML={{ __html: m.raw }} />
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input bar */}
      <div style={styles.inputRow}>
        <input
          style={styles.input}
          value={input}
          placeholder="Type a message…"
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && sendMessage()}
        />
        <button style={styles.button} onClick={sendMessage}>
          Send
        </button>
      </div>
    </div>
  );
}

export function AdminShell() {
  const [output, setOutput] = useState<string[]>([]);
  const [cmd, setCmd] = useState("");
  const [status, setStatus] = useState<"connecting" | "open" | "closed">("connecting");
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    // ❌  VULN: no admin credential sent — endpoint is open to any visitor
    const ws = new WebSocket(`${WS_BASE}/ws/admin/diag`);
    wsRef.current = ws;
    ws.onopen = () => setStatus("open");
    ws.onclose = () => setStatus("closed");
    ws.onmessage = (e) =>
      setOutput((prev) => [...prev, e.data as string]);
    return () => ws.close();
  }, []);

  const runCmd = () => {
    if (!cmd.trim() || wsRef.current?.readyState !== WebSocket.OPEN) return;
    // ❌  VULN: raw user input forwarded directly to the server shell
    wsRef.current.send(JSON.stringify({ cmd }));
    setCmd("");
  };

  return (
    <div style={{ ...styles.wrapper, background: "#0d0d0d" }}>
      <header style={styles.header}>
        <span style={styles.title}>🖥 Admin Diagnostic Shell</span>
        <span style={{ ...styles.badge, background: statusColor(status) }}>
          {status}
        </span>
      </header>

      <div style={{ ...styles.messages, fontFamily: "monospace", fontSize: 13 }}>
        {output.map((line, i) => (
          <div key={i} style={{ color: "#39ff14", whiteSpace: "pre-wrap" }}>
            {line}
          </div>
        ))}
      </div>

      <div style={styles.inputRow}>
        <input
          style={{ ...styles.input, fontFamily: "monospace" }}
          value={cmd}
          placeholder='{"cmd": "whoami"}'
          onChange={(e) => setCmd(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && runCmd()}
        />
        <button style={{ ...styles.button, background: "#39ff14", color: "#000" }} onClick={runCmd}>
          Run
        </button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Helpers & minimal inline styles
// ---------------------------------------------------------------------------
function statusColor(s: string) {
  return s === "open" ? "#22c55e" : s === "connecting" ? "#f59e0b" : "#ef4444";
}

const styles: Record<string, React.CSSProperties> = {
  wrapper: {
    display: "flex",
    flexDirection: "column",
    height: 480,
    width: "100%",
    maxWidth: 640,
    border: "1px solid #333",
    borderRadius: 8,
    overflow: "hidden",
    background: "#111",
    color: "#eee",
    fontFamily: "sans-serif",
  },
  header: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "10px 16px",
    borderBottom: "1px solid #333",
    background: "#1a1a1a",
  },
  title: { fontWeight: 700, fontSize: 15 },
  badge: {
    fontSize: 11,
    padding: "2px 8px",
    borderRadius: 999,
    color: "#fff",
    fontWeight: 600,
  },
  messages: {
    flex: 1,
    overflowY: "auto",
    padding: 16,
    display: "flex",
    flexDirection: "column",
    gap: 8,
  },
  bubble: {
    background: "#1e1e1e",
    borderRadius: 6,
    padding: "6px 12px",
    fontSize: 14,
    lineHeight: 1.5,
  },
  inputRow: {
    display: "flex",
    borderTop: "1px solid #333",
    padding: 10,
    gap: 8,
  },
  input: {
    flex: 1,
    background: "#1a1a1a",
    border: "1px solid #444",
    borderRadius: 6,
    color: "#eee",
    padding: "8px 12px",
    fontSize: 14,
    outline: "none",
  },
  button: {
    background: "#3b82f6",
    color: "#fff",
    border: "none",
    borderRadius: 6,
    padding: "8px 18px",
    cursor: "pointer",
    fontWeight: 600,
    fontSize: 14,
  },
};