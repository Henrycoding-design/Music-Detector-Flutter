import 'dart:async';
import 'dart:io' show Directory, Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/history_item.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/parse_result.dart';
import 'loading_animation.dart';

class RecognitionPage extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool? isDarkMode;
  final ValueChanged<bool> onLoadingChanged;

  const RecognitionPage({
    super.key,
    this.onToggleTheme,
    this.isDarkMode,
    required this.onLoadingChanged,
  });

  @override
  State<RecognitionPage> createState() => _RecognitionPageState();
}

class _RecognitionPageState extends State<RecognitionPage>
    with SingleTickerProviderStateMixin {
  // Input Selection State
  PlatformFile? _selectedFile;
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _fileFieldKey = GlobalKey<FormFieldState<PlatformFile>>();
  final _urlFieldKey = GlobalKey<FormFieldState<String>>();

  // Shared Core Processing State
  bool _isLoading = false;
  List<SongGuess> _guesses = [];
  String? _errorMessage;

  // validation guards
  bool _fileTouched = false;
  bool _urlTouched = false;
  bool _submitted = false;

  // Recording State & Controller
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _recordFinished = false;
  String? _recordPath;
  Uint8List? _recordBytes;
  Timer? _recordTimer;
  int _recordedSeconds = 0;
  static const int _minRecordSeconds = 15;
  static const int _maxRecordSeconds = 60;

  // To fetch tab index
  late final TabController _tabController;
  bool _isFileHovered = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _submitted = false;
          _errorMessage = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text("Microphone permission is required to record audio."),
            ),
          );
        }
        return;
      }
    }

    _recordTimer?.cancel();
    setState(() {
      _isRecording = true;
      _recordFinished = false;
      _recordPath = null;
      _recordBytes = null;
      _recordedSeconds = 0;
      _errorMessage = null;
      _guesses.clear();
    });

    String? path;
    if (!kIsWeb) {
      final tempDir = Directory.systemTemp;
      path =
          '${tempDir.path}${Platform.pathSeparator}rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    try {
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path ?? '',
      );

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _recordedSeconds++;
        });

        if (_recordedSeconds >= _maxRecordSeconds) {
          _stopRecording();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error starting recording: $e")),
        );
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        Uint8List? bytes;
        if (kIsWeb && path != null) {
          try {
            final res = await http.get(Uri.parse(path));
            bytes = res.bodyBytes;
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordFinished = true;
            _recordPath = path;
            _recordBytes = bytes;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error stopping recording: $e")),
          );
          setState(() {
            _isRecording = false;
          });
        }
      }
    }
  }

  Future<void> _resetRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (_isRecording) {
      try {
        await _audioRecorder.stop();
      } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _recordFinished = false;
      _recordPath = null;
      _recordBytes = null;
      _recordedSeconds = 0;
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true, // For flutter web
    );

    if (result == null) return;

    setState(() {
      _selectedFile = result.files.first;
      _guesses = [];
      _errorMessage = null;
    });
  }

  String _audioFileInfo() {
    if (_selectedFile == null) return "No audio file selected.";
    final sizeMB = (_selectedFile!.size / 1024 / 1024).toStringAsFixed(2);
    return "${_selectedFile!.name} ($sizeMB MB)";
  }

  // Unified request handling pipeline
  Future<void> _executeRecognition(
      Future<dynamic> Function() apiCall, bool isUrl) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _guesses.clear();
    });
    widget.onLoadingChanged(true);

    try {
      final result = await apiCall();
      final parsedGuesses = ResultParser.parse(result);
      setState(() {
        _guesses = parsedGuesses;
      });

      // Save to local history immediately after successful recognition
      final String input;
      if (isUrl) {
        input = _urlController.text.trim();
      } else if (_tabController.index == 2) {
        input = 'Voice Recording (${_recordedSeconds}s)';
      } else {
        input = _selectedFile?.name ?? 'Unknown file';
      }

      await HistoryService.save(
        HistoryItem(
          input: input,
          isUrl: isUrl,
          timestamp: DateTime.now(),
          results: parsedGuesses,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      widget.onLoadingChanged(false);
    }
  }

  void _recognize() {
    setState(() {
      _submitted = true;
    });

    if (_tabController.index == 0) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      setState(() {
        // clear url input
        _urlController.clear();
      });
      _executeRecognition(
        () => ApiService.recognize(_selectedFile!),
        false, // is not from URL
      );
    } else if (_tabController.index == 1) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      setState(() {
        // clear file input
        _selectedFile = null;
      });
      _executeRecognition(
        () => ApiService.urlRecognize(_urlController.text.trim()),
        true, // is from URL
      );
    } else if (_tabController.index == 2) {
      if (_isRecording) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Recording in progress. Will stop recording after 59s."),
          ),
        );
        return;
      }
      if (!_recordFinished || _recordPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Please record an audio sample (minimum 15 seconds) first."),
          ),
        );
        return;
      }
      if (!_formKey.currentState!.validate()) {
        return;
      }
      _executeRecognition(
        () => ApiService.recordingRecognize(_recordPath!, bytes: _recordBytes),
        false,
      );
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

  Widget _buildEmptyResultsView(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 80,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                "No results yet",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Select an audio file, paste a link, or record audio, then click 'Identify Track' to see results.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    final List<Widget> inputWidgets = [
      // Modern Tab Bar Slider Accent
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          indicator: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(
                height: 44,
                icon: Icon(Icons.audio_file_rounded, size: 20),
                text: "Audio File"),
            Tab(
                height: 44,
                icon: Icon(Icons.link_rounded, size: 20),
                text: "Stream URL"),
            Tab(
                height: 44,
                icon: Icon(Icons.mic_rounded, size: 20),
                text: "Record"),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Wrap entire TabBarView in Form
      Form(
        key: _formKey,
        child: SizedBox(
          height: 160,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // TAB 1: File Upload Dropzone Lookalike
              FormField<PlatformFile>(
                key: _fileFieldKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (file) {
                  if (_tabController.index != 0) return null;
                  if (!_submitted || !_fileTouched) return null;
                  if (file == null) return "Please select an audio file.";
                  return null;
                },
                initialValue: _selectedFile,
                builder: (state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isFileHovered = true),
                          onExit: (_) => setState(() => _isFileHovered = false),
                          child: GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () async {
                                    _fileTouched = true;
                                    await _pickAudioFile();
                                    state.didChange(_selectedFile);
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: _isFileHovered
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.10)
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.04),
                                border: Border.all(
                                  color: state.hasError
                                      ? theme.colorScheme.error
                                      : (_isFileHovered
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outlineVariant),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    duration: const Duration(milliseconds: 200),
                                    scale: _isFileHovered ? 1.08 : 1.0,
                                    child: Icon(
                                      _selectedFile != null
                                          ? Icons.check_circle_rounded
                                          : Icons.cloud_upload_rounded,
                                      size: 36,
                                      color: _selectedFile != null
                                          ? Colors.green
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      _audioFileInfo(),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _selectedFile != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Click to browse device storage",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (state.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 12),
                          child: Text(
                            state.errorText!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              // TAB 2: Text Form URL Input
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: _urlFieldKey,
                      controller: _urlController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: "Audio stream or video link URL",
                        hintText: "https://www.youtube.com/watch?v=...",
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (value) {
                        _urlTouched = true;
                        if (_errorMessage != null || _guesses.isNotEmpty) {
                          setState(() {
                            _errorMessage = null;
                            _guesses.clear();
                          });
                        }
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (_tabController.index != 1) return null;
                        if (!_submitted || !_urlTouched) return null;
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
                    const SizedBox(height: 8),
                    Text(
                      "Supports direct sound streams, videos, or shared clouds.",
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // TAB 3: Mic Recording Tab
              FormField<String>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (_) {
                  if (_tabController.index != 2) return null;
                  if (!_submitted) return null;
                  if (_isRecording) {
                    return "Recording is in progress. Please wait until at least 15s before stopping.";
                  }
                  if (!_recordFinished || _recordPath == null) {
                    return "Please record audio (at least 15 seconds) first.";
                  }
                  return null;
                },
                builder: (state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.04),
                            border: Border.all(
                              color: state.hasError
                                  ? theme.colorScheme.error
                                  : (_isRecording
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_isRecording && !_recordFinished) ...[
                                IconButton.filledTonal(
                                  onPressed:
                                      _isLoading ? null : _startRecording,
                                  icon: const Icon(Icons.mic_rounded, size: 32),
                                  iconSize: 32,
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(14),
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    foregroundColor: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tap to Start Recording",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Minimum 15s • Maximum 60s",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ] else if (_isRecording) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.fiber_manual_record_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Recording... ${_recordedSeconds.toString().padLeft(2, '0')}s / 60s",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _recordedSeconds / 60.0,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _recordedSeconds >= _minRecordSeconds
                                          ? Colors.green
                                          : theme.colorScheme.primary,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed:
                                      _recordedSeconds >= _minRecordSeconds
                                          ? _stopRecording
                                          : null,
                                  icon: const Icon(Icons.stop_rounded),
                                  label: Text(
                                    _recordedSeconds >= _minRecordSeconds
                                        ? "Stop Recording"
                                        : "Stop (available in ${_minRecordSeconds - _recordedSeconds}s)",
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: theme
                                        .colorScheme.onSurface
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                              ] else if (_recordFinished) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.green, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Recorded ${_recordedSeconds}s sample",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed:
                                      _isLoading ? null : _resetRecording,
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text("Record Again"),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (state.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 12),
                          child: Text(
                            state.errorText!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Primary Dynamic Call-To-Action Button
      FilledButton.icon(
        onPressed: _isLoading ? null : _recognize,
        icon: const Icon(Icons.music_note_rounded),
        label: const Text("Identify Track",
            style: TextStyle(fontWeight: FontWeight.bold)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      const SizedBox(height: 12),

      if (_isLoading)
        const Center(
            child: GlowingLoadingIndicator(
          title: "Recognizing song...",
          subtitle: "This may take up to 2 minutes for some URLs.",
        )),
    ];

    // Single result card view template function
    Widget buildGuessCard(SongGuess guess) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column Album Art Container
                Container(
                  width: 125,
                  height: 125,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: guess.cover != null && guess.cover!.isNotEmpty
                      ? Image.network(
                          guess.cover!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.music_note_rounded,
                              size: 40,
                              color: theme.colorScheme.primary),
                        )
                      : Icon(Icons.music_note_rounded,
                          size: 40, color: theme.colorScheme.primary),
                ),
                // Right Column Meta Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guess.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text("By ${guess.artist}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(guess.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant)),
                        if (guess.releaseDate != null)
                          Text("Released: ${guess.releaseDate}",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${(guess.confidence * 100).toStringAsFixed(0)}% Match Precision",
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Footer Content Tags & Launch Out Action
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: guess.genres.isNotEmpty
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ...guess.genres.take(isWide ? 5 : 2).map((genre) {
                                return Chip(
                                  label: Text(genre,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHigh,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                );
                              }),
                              if ((isWide && guess.genres.length > 5) ||
                                  (!isWide && guess.genres.length > 2))
                                Chip(
                                  label: Text(
                                      '+${guess.genres.length - (isWide ? 5 : 3)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHigh,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                            ].toList(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (guess.shazamUrl != null && guess.shazamUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _launchUrl(guess.shazamUrl!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text("Shazam",
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final Widget resultsWidget = _errorMessage != null
        ? Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        : ListView.builder(
            itemCount: _guesses.length,
            itemBuilder: (context, index) => buildGuessCard(_guesses[index]),
          );

    final Widget wideResultsWidget = _errorMessage != null
        ? Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        : _guesses.isEmpty
            ? _buildEmptyResultsView(theme)
            : ListView.builder(
                itemCount: _guesses.length,
                itemBuilder: (context, index) =>
                    buildGuessCard(_guesses[index]),
              );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Pane: Inputs Only
          Expanded(
            flex: 11,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: inputWidgets,
                  ),
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          // Right Pane: Results Only
          Expanded(
            flex: 9,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Identification Results",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(child: wideResultsWidget),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Narrow Screen/Mobile Layout (Unchanged)
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...inputWidgets,
              const SizedBox(height: 16),
              Expanded(
                child: resultsWidget,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
