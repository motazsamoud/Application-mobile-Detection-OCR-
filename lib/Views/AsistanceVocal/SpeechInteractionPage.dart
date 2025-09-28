import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version1/Views/AsistanceVocal/VoiceRecordingPage.dart';

class SpeechInteractionPage extends StatefulWidget {
  const SpeechInteractionPage({super.key});

  @override
  _SpeechInteractionPageState createState() => _SpeechInteractionPageState();
}

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required this.text, required this.isUser}) : timestamp = DateTime.now();
}

class _SpeechInteractionPageState extends State<SpeechInteractionPage> with SingleTickerProviderStateMixin {
  bool isListening = false;
  bool isAIResponding = false;
  String userMessage = '';
  String aiResponse = '';
  bool _isSpeechInitialized = false;
  List<Message> conversationHistory = [];
  final SpeechToText _speechToText = SpeechToText();
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  static const String _geminiApiKey = 'AIzaSyB-lwjXMpc6O-pb7ZYSkXpNynowfQLwKKU';

  static const String _customInstruction = '''
You are a friendly and user vocal assistant designed to help anything in Tunisian dialect (Derja) only.

⚠️ Do NOT use Modern Standard Arabic or English under any circumstance.

✅ Always respond in spoken Tunisian (Derja), using natural words and expressions as Tunisians use in everyday conversations. Avoid formal Arabic and foreign translations.

Your responses should be:
- Short (5–7 words)
- Clear and simple to understand
- Friendly, warm, and reassuring

You can:
- Gently remind about daily tasks (e.g., medication, eating)
- Help with orientation (e.g., place, family)
- Ask simple, engaging questions

If a question is repeated, answer users with a slightly varied reply.

Keep the conversation slow, kind, and positive at all times.
''';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final enabled = await _speechToText.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (error) => debugPrint('Speech error: $error'),
      );
      if (mounted) {
        setState(() => _isSpeechInitialized = enabled);
      }
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      if (mounted) {
        setState(() => _isSpeechInitialized = false);
      }
    }
  }


  void _startListening() async {
    if (!_isSpeechInitialized) return;

    setState(() {
      isListening = true;
      userMessage = '';
      _animationController.repeat();
    });

    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
      localeId: 'ar-TN',
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        isListening = false;
        _animationController.stop();
      });
    }
    if (userMessage.trim().isNotEmpty) {
      setState(() {
        conversationHistory.add(Message(text: userMessage, isUser: true));
      });
      await _handleAIResponse();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        userMessage = result.recognizedWords.toLowerCase();
      });
    }

    if (userMessage.contains("call issam") ||
        userMessage.contains("كلم عصام") ||
        userMessage.contains("كلم لي ولدي") ||
        userMessage.contains("كلم ولدي") ||
        userMessage.contains("تكلم عصام")) {
      _stopListening();
      _makePhoneCall("+21625786329");
      return;
    }

    if (userMessage.contains("ذكرني ناخو الدوا") ||
        userMessage.contains("فكرني ناخو الدوا") ||
        userMessage.contains("فكرني ناخذ الدواء") ||
        userMessage.contains("فكرني ناخذ الدوا")) {
      _scheduleReminder("خوذ الدوا", DateTime.now().add(const Duration(seconds: 10)));
    }

    if (result.finalResult) {
      _stopListening();
    }
  }

  String _getConversationContext() {
    final relevantHistory = conversationHistory.length > 10
        ? conversationHistory.sublist(conversationHistory.length - 10)
        : conversationHistory;

    String context = "Previous conversation:\n";
    for (var message in relevantHistory) {
      context += "${message.isUser ? 'User' : 'Assistant'}: ${message.text}\n";
    }
    return context;
  }

  Future<void> _handleAIResponse() async {
    if (mounted) {
      setState(() {
        isAIResponding = true;
        _animationController.repeat();
      });
    }

    final conversationContext = _getConversationContext();

    try {
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _geminiApiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': _customInstruction},
                {
                  'text': 'Current conversation history:\n$conversationContext\nUser\'s latest message: $userMessage\nPlease respond to this latest message with the conversation context in mind:'
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponseText = data['candidates'][0]['content']['parts'][0]['text'] ?? 'ما فماش رد من الـ AI';

        if (mounted) {
          setState(() {
            aiResponse = aiResponseText;
            conversationHistory.add(Message(text: aiResponseText, isUser: false));
          });
          await _speakWithResemble(aiResponseText);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            aiResponse = 'خطأ: ${response.statusCode}';
            conversationHistory.add(Message(text: aiResponse, isUser: false));
          });
          print('Response status: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aiResponse = 'مشكلة: $e';
          conversationHistory.add(Message(text: aiResponse, isUser: false));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isAIResponding = false;
          _animationController.stop();
        });
      }
    }
  }

  Future<void> _speakWithPlayHT(String text) async {
    if (text.trim().isEmpty) return;
    const String apiKey = 'ak-0a793beda67745669bf4aca1c2f98a53'; // Replace with your PlayHT API key
    const String userId = 'SY9YsgOpgvV6m8dT6URlDqup3Gf2'; // Replace with your PlayHT user ID
    final prefs = await SharedPreferences.getInstance();
    final voiceId = prefs.getString('playht_voice_id') ?? 's3://voice-cloning-zero-shot/d9ff78ba-d016-47f6-b0cd-dd8d6928566d/original/manifest.json'; // Fallback to Arabella

    try {
      final response = await http.post(
        Uri.parse('https://api.play.ht/api/v2/tts'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'X-User-Id': userId,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'voice': voiceId,
          'voice_engine': 'PlayHT2.0',
          'sample_rate': 24000,
          'format': 'mp3',
          'speed': 1.0,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final audioUrl = data['audioUrl'];
        if (audioUrl != null) {
          final player = AudioPlayer();
          await player.play(UrlSource(audioUrl));
        } else {
          debugPrint('No audio URL in response: $data');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to retrieve audio")),
          );
        }
      } else {
        debugPrint('TTS Error ${response.statusCode}: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("TTS error: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint('TTS Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("TTS failed: $e")),
      );
    }
  }

  Future<void> _speakWithResemble(String text) async {
    if (text.trim().isEmpty) return;
    const String apiKey = '8rUT4H6CB9oAwXIxSDrkagtt';
    final prefs = await SharedPreferences.getInstance();
    final voiceId = prefs.getString('resemble_voice_id') ?? 'default-voice';
    try {
      final response = await http.post(
        Uri.parse('https://app.resemble.ai/api/v2/projects/dummy/clips'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'voice_uuid': voiceId,
          'body': text,
          'format': 'mp3',
        }),
      );
      if (response.statusCode == 200) {
        final audioUrl = jsonDecode(response.body)['audio_url'];
        final player = AudioPlayer();
        await player.play(UrlSource(audioUrl));
      } else {
        debugPrint('TTS Error ${response.statusCode}: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("TTS error: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint('TTS Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("TTS failed: $e")),
      );
    }
  }

  Future<void> _scheduleReminder(String message, DateTime time) async {
    final delay = time.difference(DateTime.now());
    if (delay.isNegative) return;

    Future.delayed(delay, () async {
      await _speakWithResemble(message);
      setState(() {
        conversationHistory.add(Message(text: "🔔 $message", isUser: false));
      });
    });
  }

  @override
  void dispose() {
    _speechToText.stop();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF723D92),
        elevation: 0,
        title: const Text('AI Assistant', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_external_on, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VoiceRecordingPage()),
              );
            },
            tooltip: 'Record Voice',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                conversationHistory.clear();
                userMessage = '';
                aiResponse = '';
              });
            },
            tooltip: 'مسح المحادثة',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFF723D92),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Center(
                child: Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              child: conversationHistory.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'ابدأ المحادثة باش تتواصل معايا',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: conversationHistory.length,
                itemBuilder: (context, index) {
                  final message = conversationHistory[index];
                  return _buildMessageBubble(message: message.text, isUser: message.isUser);
                },
              ),
            ),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: WaveformPainter(
                      animation: _animationController,
                      isActive: isListening || isAIResponding,
                      color: const Color(0xFF723D92),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FloatingActionButton(
                backgroundColor: isListening ? Colors.red : const Color(0xFF723D92),
                onPressed: _isSpeechInitialized ? (isListening ? _stopListening : _startListening) : null,
                child: Icon(
                  isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    if (!_isSpeechInitialized) return 'الصوت غير متوفر';
    if (isListening) return 'نسمع فيك...';
    if (isAIResponding) return 'الـ AI يجاوبك...';
    return 'اضغط على الميكرو باش تبدا';
  }

  Widget _buildMessageBubble({required String message, required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF723D92) : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isActive;
  final Color color;

  WaveformPainter({required this.animation, required this.isActive, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const bars = 40;
    final barWidth = size.width / bars;
    final centerY = size.height / 2;

    for (var i = 0; i < bars; i++) {
      final x = i * barWidth;
      final normalized = (i / bars) * 2 * math.pi;
      final wave = math.sin(normalized + (animation.value * 4 * math.pi));
      final barHeight = (size.height * 0.4) * wave.abs();

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      isActive != oldDelegate.isActive || animation.value != oldDelegate.animation.value;
}

Future<void> _makePhoneCall(String phoneNumber) async {
  final Uri url = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch $url';
  }
}