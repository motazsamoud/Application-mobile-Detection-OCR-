import 'package:flutter/material.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

class VoiceRecordingPage extends StatefulWidget {
  const VoiceRecordingPage({super.key});

  @override
  _VoiceRecordingPageState createState() => _VoiceRecordingPageState();
}

class _VoiceRecordingPageState extends State<VoiceRecordingPage> {
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  bool _isUploading = false;
  int _recordDuration = 0;
  int _playPosition = 0;
  int _playDuration = 0;

  final String _textToRead = "donner moi des consignes sur le marché commerciale .";

  late FlutterSoundRecord _recorder;
  late FlutterSoundPlayer _player;
  String? _recordingPath;
  Timer? _timer;
  Timer? _playTimer;
  Amplitude? _amplitude;
  Timer? _ampTimer;
  DateTime? _recordingDate;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecord();
    _player = FlutterSoundPlayer();
    _initPlayer();
    _checkExistingRecording();
  }

  Future<void> _checkExistingRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/voice_sample.m4a';
    final file = File(filePath);

    if (await file.exists()) {
      setState(() {
        _hasRecording = true;
        _recordingPath = filePath;
        file.lastModified().then((value) {
          setState(() => _recordingDate = value);
        });
      });
    }
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    _player.setSubscriptionDuration(const Duration(milliseconds: 200));
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      _recordingPath = '${directory.path}/voice_sample.m4a';

      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }

      await _recorder.start(path: _recordingPath);
      bool isRecording = await _recorder.isRecording();
      setState(() {
        _isRecording = isRecording;
        _recordDuration = 0;
      });
      _startTimer();
      print("Recording started...");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please grant microphone permission")),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_recordDuration < 30) {
      _timer?.cancel();
      _ampTimer?.cancel();
      await _recorder.stop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Record at least 30 seconds for cloning")),
      );
      setState(() {
        _isRecording = false;
        _hasRecording = false;
        _recordingPath = null;
      });
      return;
    }

    _timer?.cancel();
    _ampTimer?.cancel();
    final String? path = await _recorder.stop();

    setState(() {
      _isRecording = false;
      _hasRecording = path != null;
      _recordingDate = DateTime.now();
    });
    print("Recording saved at: $path");

    if (path != null) {
      await _uploadToResemble(path);
    }
  }

  Future<void> _uploadToPlayHT(String audioPath) async {
    setState(() => _isUploading = true);
    const String apiKey = 'ak-0a793beda67745669bf4aca1c2f98a53'; // Replace with your PlayHT API key
    const String userId = 'SY9YsgOpgvV6m8dT6URlDqup3Gf2'; // Replace with your PlayHT user ID
    const String cloneUrl = 'https://api.play.ht/api/v2/cloned-voices/instant';

    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Audio file not found")),
        );
        return;
      }

      final request = http.MultipartRequest('POST', Uri.parse(cloneUrl))
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..headers['X-User-Id'] = userId
        ..headers['Accept'] = 'application/json'
        ..fields['voice_name'] = 'UserVoice_${DateTime.now().millisecondsSinceEpoch}'
        ..fields['sample_file_name'] = 'voice_sample.m4a'
        ..files.add(http.MultipartFile(
          'sample_file',
          audioFile.readAsBytes().asStream(),
          audioFile.lengthSync(),
          filename: 'voice_sample.m4a',
          contentType: MediaType('audio', 'x-m4a'), // Explicitly set Content-Type
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(responseBody);
        final voiceId = responseData['id']?.toString();
        if (voiceId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('playht_voice_id', voiceId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Voice cloned successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to retrieve voice ID")),
          );
          debugPrint('Response data: $responseData');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cloning voice: $responseBody")),
        );
        debugPrint('Clone Error ${response.statusCode}: $responseBody');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
      debugPrint('Clone Exception: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadToResemble(String audioPath) async {
    print('Starting upload to Resemble with audioPath: $audioPath');
    setState(() => _isUploading = true);
    const String apiKey = '8rUT4H6CB9oAwXIxSDrkagtt'; // From resemble.ai

    try {
      final audioFile = File(audioPath);
      print('Audio file exists: ${await audioFile.exists()}');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://app.resemble.ai/api/v2/voices'),
      )
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['name'] = 'UserVoice_${DateTime.now().millisecondsSinceEpoch}';

      print('Adding audio file to request...');
      final fileToSend = await http.MultipartFile.fromPath('voice_file', audioPath);
      request.files.add(fileToSend);

      print('Sending request to Resemble...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Response status code: ${response.statusCode}');
      print('Response body: $responseBody');

      if (response.statusCode == 201) {
        final voiceId = jsonDecode(responseBody)['uuid'];
        print('Voice cloned successfully. Voice ID: $voiceId');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('resemble_voice_id', voiceId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Voice cloned successfully!")),
        );
      } else {
        print('Error cloning voice. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cloning voice: $responseBody")),
        );
      }
    } catch (e) {
      print('Exception occurred during upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      print('Upload process finished.');
      setState(() => _isUploading = false);
    }
  }


  Future<void> _playRecording() async {
    if (_isPlaying) {
      await _stopPlayback();
      return;
    }

    if (_recordingPath != null) {
      await _player.startPlayer(
        fromURI: _recordingPath!,
        whenFinished: () {
          setState(() => _isPlaying = false);
          _playTimer?.cancel();
        },
      );

      _player.onProgress!.listen((event) {
        setState(() {
          _playPosition = event.position.inMilliseconds;
          _playDuration = event.duration.inMilliseconds;
        });
      });

      setState(() => _isPlaying = true);
      _startPlayTimer();
    }
  }

  Future<void> _stopPlayback() async {
    await _player.stopPlayer();
    _playTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  Future<void> _deleteRecording() async {
    if (_isPlaying) {
      await _stopPlayback();
    }

    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('playht_voice_id');

      setState(() {
        _hasRecording = false;
        _recordingPath = null;
        _recordingDate = null;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _ampTimer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });

    _ampTimer = Timer.periodic(const Duration(milliseconds: 200), (Timer t) async {
      _amplitude = await _recorder.getAmplitude();
      setState(() {});
    });
  }

  void _startPlayTimer() {
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 200), (Timer t) {
      if (!_isPlaying) {
        _playTimer?.cancel();
      }
    });
  }

  String _formatTimer(int seconds) {
    final minutes = _formatNumber(seconds ~/ 60);
    final secs = _formatNumber(seconds % 60);
    return '$minutes:$secs';
  }

  String _formatNumber(int number) {
    return number < 10 ? '0$number' : number.toString();
  }

  String _formatPlaybackTime(int milliseconds) {
    int seconds = (milliseconds / 1000).floor();
    return _formatTimer(seconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampTimer?.cancel();
    _playTimer?.cancel();
    _recorder.dispose();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 10,
                shadowColor: const Color(0xFF723D92),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Read Aloud',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF723D92),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _textToRead,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFF723D92),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isRecording) ...[
                          const Icon(
                            Icons.mic,
                            color: Colors.red,
                            size: 80,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Recording... ${_formatTimer(_recordDuration)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          if (_amplitude != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              height: 60,
                              child: Center(
                                child: _VoiceWaveWidget(
                                  amplitude: _amplitude!.current,
                                ),
                              ),
                            ),
                          ],
                        ] else if (_hasRecording) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _isUploading ? null : _playRecording,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF723D92).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(35),
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: const Color(0xFF723D92),
                                    size: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              GestureDetector(
                                onTap: _isUploading ? null : _deleteRecording,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(35),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_isUploading) ...[
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF723D92)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Uploading to clone voice...',
                              style: TextStyle(fontSize: 16, color: Color(0xFF723D92)),
                            ),
                          ] else if (_isPlaying) ...[
                            Text(
                              'Playing... ${_formatPlaybackTime(_playPosition)} / ${_formatPlaybackTime(_playDuration)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF723D92),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: LinearProgressIndicator(
                                value: _playDuration > 0 ? _playPosition / _playDuration : 0.0,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF723D92)),
                                minHeight: 4,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Recording complete',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Press play to listen or record again',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ] else ...[
                          Icon(
                            Icons.mic_none,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No recording yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Press the button below to start recording',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!_hasRecording || _isRecording)
                FloatingActionButton.extended(
                  onPressed: _isUploading ? null : (_isRecording ? _stopRecording : _startRecording),
                  backgroundColor: _isRecording ? Colors.red : const Color(0xFF723D92),
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isRecording ? 'Stop' : (_hasRecording ? 'Re-record' : 'Start Recording'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceWaveWidget extends StatelessWidget {
  final double amplitude;

  const _VoiceWaveWidget({required this.amplitude});

  @override
  Widget build(BuildContext context) {
    double normalizedAmplitude = (amplitude + 160) / 160;
    if (normalizedAmplitude < 0) normalizedAmplitude = 0;
    if (normalizedAmplitude > 1) normalizedAmplitude = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(9, (index) {
        double height = 10 + normalizedAmplitude * 40;
        if (index % 2 == 0) height *= 0.6;
        if (index % 3 == 0) height *= 1.3;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: Container(
            width: 5,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF723D92),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        );
      }),
    );
  }
}