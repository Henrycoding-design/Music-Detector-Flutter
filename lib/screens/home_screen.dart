import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/parse_result.dart';
import './loading_animation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Input Selection State
  PlatformFile? _selectedFile;
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Shared Core Processing State
  bool _isLoading = false;
  List<SongGuess> _guesses = [];
  String? _errorMessage;

  // to fetch tab index
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true, // Required for Flutter Web
    );

    if (result == null) return;

    setState(() {
      _selectedFile = result.files.first;
      _guesses = [];
      _errorMessage = null;
    });
  }

  String _audioFileInfo() {
    if (_selectedFile == null) {
      return "No audio file selected.";
    }

    final sizeMB = (_selectedFile!.size / 1024 / 1024).toStringAsFixed(2);

    return '''
Selected: ${_selectedFile!.name}
File size: $sizeMB MB
''';
  }

  // Unified Request Handling Pipeline
  Future<void> _executeRecognition(Future<dynamic> Function() apiCall) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _guesses.clear();
    });

    try {
      final result = await apiCall();
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

  // File recognition entry point
  void _recognizeFile() {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an audio file first.")),
      );
      return;
    }

    // clear the url input before file recognition starts
    setState((){
      _urlController.clear();
    });

    _executeRecognition(() => ApiService.recognize(_selectedFile!));
  }

  // URL recognition entry point
  void _recognizeUrl() {
    if (_formKey.currentState?.validate() ?? false) {

      //clear the file input before url recognition starts
      setState((){
        _selectedFile = null;
      });
     
      _executeRecognition(() => ApiService.urlRecognize(_urlController.text.trim()));
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch $urlString")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                  // Tab Selection Switches
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(icon: Icon(Icons.audio_file), text: "Audio File"),
                        Tab(icon: Icon(Icons.link), text: "Stream URL"),
                      ],
                      onTap: (_) {
                        // // Clear output state when users switch methods to avoid context cluttering
                        // setState(() {
                        //   _errorMessage = null;
                        //   _guesses.clear();
                        // });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Swappable Input Section Viewport
                  SizedBox(
                    height: 120, 
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(), // Keeps inputs stable
                      children: [
                        // TAB 1: File Selection UI
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _pickAudioFile,
                              icon: const Icon(Icons.search),
                              label: const Text("Select Audio File"),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(_audioFileInfo(), style: const TextStyle(fontSize: 14)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // TAB 2: URL Form Input UI
                        Form(
                          key: _formKey,
                          child: Padding( 
                            padding: EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _urlController,
                                  enabled: !_isLoading,
                                  decoration: const InputDecoration(
                                    labelText: "Audio stream or video link URL",
                                    hintText: "https://www.youtube.com/watch?v=...",
                                    prefixIcon: Icon(Icons.link),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.url,
                                  onChanged: (value) {
                                    // Only call setState if there is actually state to clear
                                    if (_errorMessage != null || _guesses.isNotEmpty) {
                                      setState(() {
                                        _errorMessage = null;
                                        _guesses.clear();
                                      });
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Please enter a destination web address link.";
                                    }

                                    final uri = Uri.tryParse(value.trim());

                                    if (uri == null ||
                                        !uri.hasAbsolutePath ||
                                        !(uri.scheme == 'http' || uri.scheme == 'https') ||
                                        uri.host.isEmpty) {
                                      return "Please enter a valid HTTP or HTTPS URL.";
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Supports direct link audio files, video links or shared cloud attachments.",
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Unified Dynamic Call-To-Action Switch
                  Builder(
                    builder: (context) {
                      final tabIndex = _tabController.index;
                      return ElevatedButton.icon(
                        onPressed: _isLoading 
                            ? null 
                            : () => tabIndex == 0 ? _recognizeFile() : _recognizeUrl(),
                        icon: const Icon(Icons.music_note),
                        label: const Text("Identify Song"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  if (_isLoading)
                    const Center(child: GlowingLoadingIndicator(),),

                  // Unified Parsing Results Render Area
                  Expanded(
                    child: _errorMessage != null
                        ? Card(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _guesses.length,
                            itemBuilder: (context, index) {
                              final guess = _guesses[index];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.grey[300],
                                          child: guess.cover != null && guess.cover!.isNotEmpty
                                              ? Image.network(
                                                  guess.cover!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(Icons.music_note, size: 50),
                                                )
                                              : const Icon(Icons.music_note, size: 50),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  guess.title,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text("Artist: ${guess.artist}", maxLines: 1, overflow: TextOverflow.ellipsis),
                                                Text("Album: ${guess.album}", maxLines: 1, overflow: TextOverflow.ellipsis),
                                                if (guess.releaseDate != null)
                                                  Text("Released: ${guess.releaseDate}"),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Confidence: ${(guess.confidence * 100).toStringAsFixed(1)}%",
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (guess.genres.isNotEmpty) ...[
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: guess.genres.map((genre) {
                                                return Chip(
                                                  label: Text(genre, style: const TextStyle(fontSize: 12)),
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  padding: EdgeInsets.zero,
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (guess.shazamUrl != null && guess.shazamUrl!.isNotEmpty)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed: () => _launchUrl(guess.shazamUrl!),
                                                icon: const Icon(Icons.open_in_new, size: 18),
                                                label: const Text("Open in Shazam"),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }
}