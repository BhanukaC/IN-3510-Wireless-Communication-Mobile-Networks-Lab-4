import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MyApp());

/// Resolve the correct WebSocket URL depending on where the app runs.
///
/// Why this matters:
/// - **Web**: your page runs in a browser; if the page is http:// you must
///   connect with `ws://`, and if https:// you must use `wss://`.
/// - **Android emulator**: `localhost` inside the emulator is *the emulator*,
///   not your host machine. Use `10.0.2.2` to reach the host.
/// - **iOS simulator / desktop**: `localhost` reaches your machine directly.
/// - **Real devices**: replace `localhost` with your computer’s LAN IP
///   (e.g., `ws://192.168.1.23:8080`) and make sure the firewall allows it.
String resolveWsUrl() {
  if (kIsWeb) {
    // If your site is served via HTTPS, change to wss://localhost:8080
    return 'ws://localhost:8080';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    // Magic host to reach your development machine from Android emulator.
    return 'ws://10.0.2.2:8080';
  }

  // iOS simulator / macOS / Windows / Linux
  return 'ws://localhost:8080';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'WebSocket Chat',
      home: ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// The channel abstracts the socket; we’ll use IOWebSocketChannel so we can
  /// set `pingInterval` (keeps the connection alive through NAT/idle proxies).
  late final WebSocketChannel _channel;

  /// Text input for the chat box.
  final _controller = TextEditingController();

  /// Simple message log for the ListView.
  final List<String> _messages = [];


  /// Rough one-way latency estimate (ms) computed from a server timestamp
  /// included with “clock” messages.
  int? _latencyMs;

  @override
  void initState() {
    super.initState();

    final url = resolveWsUrl();
    debugPrint('Connecting to $url');

    // Create the socket and start listening to frames from the server.
    // NOTE: If you later want auto-reconnect, wrap this into a method
    // that can be called again on close with backoff.
    _channel = IOWebSocketChannel.connect(
      Uri.parse(url),
      // Sends WebSocket-level pings every 15s (server should answer with pongs).
      pingInterval: const Duration(seconds: 15),
    );

    // Subscribe to the incoming stream of frames.
    _channel.stream.listen(
          (data) {
        // Each `data` is typically a JSON string from the Node server.
        try {
          final obj = jsonDecode(data.toString()) as Map<String, dynamic>;
          final type = obj['type'];

          // Your Node server currently sends:
          //  - { type: "welcome", message }
          //  - { type: "chat", message }
          // renders it in the app bar and computes latency.
          if (type == 'welcome') {
            setState(() => _messages.add('Server: ${obj['message']}'));
          } else if (type == 'chat') {
            setState(() => _messages.add('Server: ${obj['message']}'));
          } else {
            // Future-friendly: show unknown structured messages.
            setState(() => _messages.add('Server(unknown): $obj'));
          }
        } catch (_) {
          // Not JSON? Just show the raw string.
          setState(() => _messages.add('Server(raw): $data'));
        }
      },
      onDone: () {
        // Called when the server closes the connection.
        setState(() => _messages.add('🔌 Connection closed'));
        debugPrint(
            'WS done (code: ${_channel.closeCode}, reason: ${_channel.closeReason})');
      },
      onError: (err, st) {
        // Non-fatal here; we keep the UI alive and show the error.
        setState(() => _messages.add('⚠️ WS error: $err'));
        debugPrint('WS error: $err');
      },
      cancelOnError: false, // keep stream alive after onError
    );
  }

  /// Send a chat message to the server.
  ///
  /// The server echoes/broadcasts `{ type: "chat", message }` to all clients.
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final payload =
    jsonEncode({'type': 'chat', 'message': text, 'device': 'mobile'});
    try {
      _channel.sink.add(payload);
      setState(() => _messages.add('You: $text'));
    } catch (e) {
      setState(() => _messages.add('❌ Send failed: $e'));
    }
    _controller.clear();
  }

  @override
  void dispose() {
    // Always close the socket and dispose controllers.
    _channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("WebSocket Chat"),
      ),
      body: Column(
        children: [
          // Scrollable message list.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                title: Text(_messages[i]),
              ),
            ),
          ),
          // Input area.
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message… (try 'time')",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  label: const Text("Send"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
