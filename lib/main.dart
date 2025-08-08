import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SongbookApp());
}

class SongbookApp extends StatelessWidget {
  const SongbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Songbook',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? gistId;
  Map<String, String> files = {}; // filename -> content
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadGistId();
  }

  Future<void> _loadGistId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      gistId = prefs.getString('gist_id');
    });
    if (gistId != null && gistId!.isNotEmpty) {
      _fetchGist();
    }
  }

  Future<void> _saveGistId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gist_id', id);
    setState(() {
      gistId = id;
    });
    _fetchGist();
  }

  Future<void> _fetchGist() async {
    if (gistId == null || gistId!.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      files = {};
    });
    try {
      final url = Uri.parse('https://api.github.com/gists/$gistId');
      final res = await http.get(url);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final f = data['files'] as Map<String, dynamic>?;
      if (f == null || f.isEmpty) {
        throw Exception('No files in gist');
      }
      final Map<String, String> loaded = {};
      for (final entry in f.entries) {
        final name = entry.key;
        final content = entry.value['content'] as String? ?? '';
        loaded[name] = content;
      }
      setState(() {
        files = loaded;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Map<String, List<String>> groupedByArtist() {
    final Map<String, List<String>> m = {};
    for (final name in files.keys) {
      // Expect format "Artist - Title.txt" or similar
      final base = name.replaceAll('.txt', '');
      final parts = base.split(' - ');
      String artist = 'Unknown';
      String title = base;
      if (parts.length >= 2) {
        artist = parts.first.trim();
        title = parts.sublist(1).join(' - ').trim();
      }
      m.putIfAbsent(artist, () => []).add(title);
    }
    // sort lists
    for (final v in m.values) {
      v.sort();
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupedByArtist();
    return Scaffold(
      appBar: AppBar(title: const Text('Songbook')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: gistId ?? '',
                decoration: const InputDecoration(
                  labelText: 'Gist ID (or leave empty for none)',
                ),
                onFieldSubmitted: (v) => _saveGistId(v.trim()),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _fetchGist,
              child: const Text('Fetch'),
            )
          ]),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text('Error: $error', style: const TextStyle(color: Colors.red)),
          Expanded(
            child: ListView(
              children: grouped.keys.map((artist) {
                return ExpansionTile(
                  title: Text(artist),
                  children: grouped[artist]!.map((title) {
                    final filename = files.keys.firstWhere((k) {
                      final base = k.replaceAll('.txt','');
                      final parts = base.split(' - ');
                      if (parts.length >= 2) {
                        final a = parts.first.trim();
                        final t = parts.sublist(1).join(' - ').trim();
                        return a == artist && t == title;
                      } else {
                        return base == title;
                      }
                    });
                    return ListTile(
                      title: Text(title),
                      onTap: () {
                        final content = files[filename]!;
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SongScreen(title: title, content: content)));
                      },
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

class SongScreen extends StatefulWidget {
  final String title;
  final String content;
  const SongScreen({super.key, required this.title, required this.content});

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> {
  final ScrollController _scrollController = ScrollController();
  double speed = 30; // pixels per second
  Timer? _timer;
  bool auto = false;

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void toggleAuto() {
    setState(() {
      auto = !auto;
    });
    _timer?.cancel();
    if (auto) {
      const tickMs = 100;
      _timer = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
        final dy = speed * tickMs / 1000;
        _scrollController.jumpTo((_scrollController.offset + dy).clamp(0.0, _scrollController.position.maxScrollExtent));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(icon: Icon(auto ? Icons.pause : Icons.play_arrow), onPressed: toggleAuto),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          Slider(
            min: 10,
            max: 200,
            value: speed,
            onChanged: (v) => setState(() { speed = v; }),
          ),
          Expanded(child: SingleChildScrollView(
            controller: _scrollController,
            child: SelectableText(widget.content, style: const TextStyle(fontSize: 18, height: 1.4)),
          ))
        ]),
      ),
    );
  }
}
