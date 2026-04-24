import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// MyKad OCR Screen — tap to camera or gallery, Gemini Vision extracts fields
class MyKadOcrScreen extends StatefulWidget {
  final void Function(Map<String, String> extracted) onExtracted;
  const MyKadOcrScreen({super.key, required this.onExtracted});

  @override
  State<MyKadOcrScreen> createState() => _MyKadOcrScreenState();
}

class _MyKadOcrScreenState extends State<MyKadOcrScreen> {
  bool _processing = false;
  Map<String, String>? _result;
  String? _error;

  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  Future<void> _pickAndExtract(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    setState(() { _processing = true; _error = null; _result = null; });

    try {
      if (_geminiKey.isEmpty) throw Exception('GEMINI_API_KEY not set');
      final bytes = await file.readAsBytes();
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _geminiKey);
      final resp = await model.generateContent([
        Content.multi([
          TextPart('''Extract the following from this Malaysian MyKad (National ID card) photo.
Return ONLY valid JSON with these keys (leave empty string if not visible):
{
  "full_name": "",
  "ic_number": "",
  "address": "",
  "date_of_birth": "",
  "gender": "",
  "nationality": ""
}'''),
          DataPart('image/jpeg', bytes),
        ])
      ]);
      final raw = (resp.text ?? '{}').replaceAll(RegExp(r'```json?\n?'), '').replaceAll('```', '').trim();
      final extracted = _parseFields(raw);
      setState(() { _result = extracted; _processing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _processing = false; });
    }
  }

  Map<String, String> _parseFields(String json) {
    Map<String, String> fields = {};
    for (final key in ['full_name', 'ic_number', 'address', 'date_of_birth', 'gender', 'nationality']) {
      final match = RegExp('"$key"\\s*:\\s*"([^"]*)"').firstMatch(json);
      fields[key] = match?.group(1) ?? '';
    }
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imbas MyKad / Scan MyKad')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A2A))),
          child: const Column(children: [
            Icon(Icons.badge, color: Color(0xFFE53935), size: 48),
            SizedBox(height: 12),
            Text('Imbas MyKad anda untuk mengisi profil secara automatik.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF757575))),
            Text('Scan your MyKad to auto-fill your profile.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF505050), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _ActionBtn(
            icon: Icons.camera_alt, label: 'Kamera\nCamera',
            onTap: () => _pickAndExtract(ImageSource.camera),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ActionBtn(
            icon: Icons.photo_library, label: 'Galeri\nGallery',
            onTap: () => _pickAndExtract(ImageSource.gallery),
          )),
        ]),
        if (_processing) ...[
          const SizedBox(height: 32),
          const Center(child: Column(children: [
            CircularProgressIndicator(color: Color(0xFFE53935), strokeWidth: 3),
            SizedBox(height: 12),
            Text('Gemini Vision sedang menganalisis...', style: TextStyle(color: Color(0xFF757575))),
            Text('Gemini Vision is analysing...', style: TextStyle(color: Color(0xFF505050), fontSize: 12)),
          ])),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE53935).withAlpha(20), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE53935).withAlpha(80))),
            child: Row(children: [
              const Icon(Icons.warning_amber, color: Color(0xFFE53935), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: $_error', style: const TextStyle(color: Color(0xFFE53935), fontSize: 12))),
            ]),
          ),
        ],
        if (_result != null && _result!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('HASIL IMBASAN / SCAN RESULTS', style: TextStyle(color: Color(0xFF757575), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF00C853).withAlpha(10), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF00C853).withAlpha(60))),
            child: Column(children: [
              ..._result!.entries.where((e) => e.value.isNotEmpty).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 120, child: Text(e.key.replaceAll('_', ' '), style: const TextStyle(color: Color(0xFF757575), fontSize: 12))),
                  Expanded(child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                ]),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () { widget.onExtracted(_result!); Navigator.pop(context); },
            icon: const Icon(Icons.check),
            label: const Text('GUNA DATA INI / USE THIS DATA'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.white),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() { _result = null; }),
            child: const Text('Cuba Lagi / Try Again', style: TextStyle(color: Color(0xFF757575))),
          ),
        ],
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 100,
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFFE53935), size: 36),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF757575), fontSize: 12)),
      ]),
    ),
  );
}
