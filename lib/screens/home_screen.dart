import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/parse_result.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  List<SongGuess> _guesses = [];
  String? _errorMessage;

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true, // Required for Flutter Web
    );

    if (result == null) return;

    setState(() {
      _selectedFile = result.files.first;
      _guesses = [];
    });
  }

  String _audioFileInfo() {
    if (_selectedFile == null) {
      return "No audio file selected.";
    }

    final sizeMB = (_selectedFile!.size / 1024 / 1024).toStringAsFixed(2);

    return '''
Selected:${_selectedFile!.name}
File size: $sizeMB
''';
  }

  Future<void> _recognize() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select an audio file first."),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _guesses.clear();
    });

    try {
      final result = await ApiService.recognize(_selectedFile!);

      setState(() {
        _guesses = ResultParser.parse(result);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Music Detector"),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickAudioFile,
                  icon: const Icon(Icons.audio_file),
                  label: const Text("Select Audio"),
                ),

                const SizedBox(height: 20),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _audioFileInfo(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _recognize,
                  icon: const Icon(Icons.music_note),
                  label: const Text("Recognize"),
                ),

                const SizedBox(height: 30),

                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),

                Expanded(
                  child: _errorMessage != null
                  ? Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  )
                  : ListView.builder(
                    itemCount: _guesses.length,
                    itemBuilder: (context, index) {
                      final guess = _guesses[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guess.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text("Artist: ${guess.artist}"),
                              Text("Album: ${guess.album}"),

                              if (guess.releaseDate != null)
                                Text("Released: ${guess.releaseDate}"),

                              if (guess.isrc != null)
                                Text("ISRC: ${guess.isrc}"),

                              const SizedBox(height: 8),

                              Text(
                                "Confidence: ${(guess.confidence * 100).toStringAsFixed(2)}%",
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}