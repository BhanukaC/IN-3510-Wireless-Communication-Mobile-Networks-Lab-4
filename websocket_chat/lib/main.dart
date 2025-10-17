import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MyApp());

String resolveWsUrl() {
  // Adjust host based on where the app is running
  if (kIsWeb) {
    // Flutter Web in the browser
    // If your dev server is http://localhost:8080 use ws://
    // If your page is served over HTTPS, use wss://localhost:8080
    return 'ws://localhost:8080';
  }
  // Mobile/desktop
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android emulator can reach host machine via 10.0.2.2
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
      title: 'WebSocket Chat + Clock',
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
  late final WebSocketChannel _channel;
  final _controller = TextEditingController();
  final List<String> _messages = [];
  String _serverClock = '—';
  int? _latencyMs;

  @override
  void initState() {
    super.initState();

    final url = resolveWsUrl();
    debugPrint('Connecting to $url');

    // Use IOWebSocketChannel so we can set pingInterval (keeps idle connections alive)
    _channel = IOWebSocketChannel.connect(
      Uri.parse(url),
      pingInterval: const Duration(seconds: 15),
    );

    _channel.stream.listen(
          (data) {
        // Log raw frames to confirm they arrive
        // debugPrint('RX: $data');
        try {
          final obj = jsonDecode(data.toString()) as Map<String, dynamic>;
          final type = obj['type'];

          if (type == 'welcome') {
            setState(() => _messages.add('Server: ${obj['message']}'));
          } else if (type == 'chat') {
            setState(() => _messages.add('Server: ${obj['message']}'));
          } else if (type == 'clock') {
            final sent = (obj['epochMs'] as num?)?.toInt();
            if (sent != null) {
              _latencyMs = DateTime.now().millisecondsSinceEpoch - sent;
            }
            setState(() => _serverClock = (obj['iso'] as String?) ?? '—');
          } else {
            setState(() => _messages.add('Server(unknown): $obj'));
          }
        } catch (e) {
          setState(() => _messages.add('Server(raw): $data'));
        }
      },
      onDone: () {
        setState(() => _messages.add('🔌 Connection closed'));
        debugPrint('WS done (code: ${_channel.closeCode}, reason: ${_channel.closeReason})');
      },
      onError: (err, st) {
        setState(() => _messages.add('⚠️ WS error: $err'));
        debugPrint('WS error: $err');
      },
      cancelOnError: false,
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final payload = jsonEncode({'type': 'chat', 'message': text,'device': 'mobile'});
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
    _channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latency = _latencyMs == null ? '—' : '${_latencyMs} ms';

    return Scaffold(
      appBar: AppBar(
        title: const Text("WebSocket Chat + Server Clock"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Server UTC: $_serverClock  |  Latency: $latency',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) => ListTile(title: Text(_messages[i])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
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
            ]),
          )
        ],
      ),
    );
  }
}
