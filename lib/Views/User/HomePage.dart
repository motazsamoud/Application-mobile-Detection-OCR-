import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:version1/Providers/AuthProvider.dart';
import 'package:version1/Views/AsistanceVocal/VoiceRecordingPage.dart';
import 'package:web_socket_channel/io.dart';
import 'package:version1/Views/User/CustomBottomNavBar.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  IOWebSocketChannel? _channel;
  bool _wsOpen = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _startVoiceAssistance(BuildContext context) async {
    if (!_wsOpen) {
      await _initWebSocket();
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VoiceRecordingPage()),
    );
  }

  Future<void> _initWebSocket() async {
    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse('wss://api.deepgram.com/v1/listen'),
        headers: const {
          'Authorization': 'Token a98ac2b8816736333008d8f5d0a5e5151ead5aa4',
          'Content-Type': 'application/json',
        },
      );

      _wsOpen = true;

      _channel!.stream.listen(
        (data) {
          final response = json.decode(data);
          final transcript = response['channel']?['alternatives']?[0]?['transcript'] ?? '';
          if (transcript.isNotEmpty) {
            debugPrint('Transcription: $transcript');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _wsOpen = false;
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _wsOpen = false;
        },
        cancelOnError: true,
      );
    } catch (e) {
      _wsOpen = false;
      debugPrint('WebSocket init failed: $e');
    }
  }

  @override
  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _wsOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.username ?? "User";

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1F), Color(0xFF001B2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 👋 Message de bienvenue avec vrai nom
                  Text(
                    "Welcome back, $userName 👋",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 📊 KPIs rapides (remplacé Montant par "Clients actifs")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statCard(Icons.trending_up, "Opportunités", "12"),
                      _statCard(Icons.people, "Clients actifs", "8"),
                      _statCard(Icons.emoji_events, "Win Rate", "42%"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ⚡ Quick Actions
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _quickAction(Icons.table_view, "Rapports"),
                      _quickAction(Icons.insights, "Statistiques"),
                      _quickAction(Icons.business, "Sociétés"),
                      _quickAction(Icons.settings, "Paramètres"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 💡 Astuce du jour
                  _glassBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("💡 Astuce du jour",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text(
                          "Analysez vos opportunités avec l’IA pour identifier vos prospects les plus prometteurs.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 📌 Actions recommandées
                  _glassBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("📌 Actions recommandées",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text("• Relancer les clients inactifs",
                            style: TextStyle(color: Colors.white70)),
                        Text("• Analyser les tendances de vente",
                            style: TextStyle(color: Colors.white70)),
                        Text("• Optimiser vos emails marketing",
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🏢 Top sociétés
                  _glassBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("🏢 Top sociétés",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text("• Company A — 5 opportunités",
                            style: TextStyle(color: Colors.white70)),
                        Text("• Company B — 3 opportunités",
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 📰 Actualités internes
                  _glassBox(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("📰 Dernières nouvelles",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text("• Nouvelle version de l’application déployée",
                            style: TextStyle(color: Colors.white70)),
                        Text("• Atelier IA prévu vendredi",
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 📈 Graphique ou placeholder
                  _glassBox(
                    Column(
                      children: [
                        const Text("📈 Progression",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        // Utilise un autre Lottie si chart.json manque
                        Lottie.asset(
                          "assets/animations/progress.json",
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),

              // 🎤 Bouton micro flottant
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 90, right: 20),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0A0F1F),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.8),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () => _startVoiceAssistance(context),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child:
                        const Icon(Icons.mic, color: Color(0xFF00E5FF), size: 36),
                  ),
                ),
              ),

              // ⬇️ BottomNavBar
              Align(
                alignment: Alignment.bottomCenter,
                child: CustomBottomNavBarUser(
                  selectedIndex: _selectedIndex,
                  onItemSelected: _onItemTapped,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00E5FF), size: 28),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {},
      icon: Icon(icon, color: const Color(0xFF00E5FF)),
      label: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _glassBox(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: child,
      );
}
