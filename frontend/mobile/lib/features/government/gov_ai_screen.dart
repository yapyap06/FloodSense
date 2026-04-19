import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import '../../core/data/gov_flood_qna.dart';
import '../../core/providers/locale_provider.dart';

class GovAIScreen extends StatefulWidget {
  const GovAIScreen({super.key});
  @override
  State<GovAIScreen> createState() => _GovAIScreenState();
}

class _GovAIScreenState extends State<GovAIScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  final _messages = <({bool isUser, String text, bool isOffTopic})>[];
  bool _loading = false;
  bool _greeted = false;

  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const _persona = '''
You are the FloodSense **Government Command Assistant** — a specialized AI supporting NADMA, Bomba, PDRM, JKM, APM, and JPS officers.

IMPORTANT RULES:
1. Answer ONLY questions related to: flood operations, MKN Directive 20 SOPs, alert levels, SOS dispatch, PPS management, BWI claims, asset deployment, and inter-agency coordination.
2. If the question is clearly unrelated to disaster management, government operations, or emergency procedures, reply EXACTLY: "IRRELEVANT"
3. Maintain a highly professional, authoritative, and concise tone appropriate for command center operations. Use bullet points for SOP steps.
4. Answer in the SAME LANGUAGE as the question (BM or English).
5. Ensure answers align with the provided Government SOP context.
''';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_greeted) {
      _greeted = true;
      final isMs = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode == 'ms';
      _messages.add((
        isUser: false,
        text: isMs 
              ? 'Sistem Dalam Talian. Pembantu Arahan dimulakan 🛡️\n\n'
                'Sedia membantu dengan Pengurusan Bencana (MKN No. 20):\n'
                '• SOP Amaran & Keselamatan (JPS/NADMA)\n'
                '• Pengurusan PPS & BWI (JKM)\n'
                '• Protokol Operasi APM / Bomba / PDRM\n\n'
                'Masukkan arahan atau pertanyaan SOP untuk bermula.'
              : 'System Online. Command Assistant initialized 🛡️\n\n'
                'Ready to assist with Disaster Management (MKN No. 20):\n'
                '• Alert & Safety SOPs (JPS/NADMA)\n'
                '• PPS & BWI Management (JKM)\n'
                '• APM / Bomba / PDRM Operational Protocols\n\n'
                'Enter a command or SOP query to begin.',
        isOffTopic: false,
      ));
    }
  }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _messages.add((isUser: true, text: q, isOffTopic: false));
      _loading = true;
    });

    final relevant = isGovRelevant(q);
    final ctx = retrieveGovSops(q).join('\n\n');
    String answer;

    final isMs = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode == 'ms';
    try {
      if (_geminiKey.isNotEmpty) {
        final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _geminiKey);
        final prompt = '$_persona\n\n'
            '${relevant ? "Official Government SOP Data:\n$ctx\n\n" : "Standard MKN 20 Guidelines apply.\n"}'
            'User Command/Query: $q\nAssistant:';
        final raw = (await model.generateContent([Content.text(prompt)])).text ?? ctx;
        if (raw.trim().toUpperCase() == 'IRRELEVANT') {
          answer = isMs ? '❌ Pertanyaan tidak sah. Pembantu ini terhad kepada rujukan Pengurusan Bencana (SOP MKN 20), PPS, Amaran, dan Operasi Menyelamat.' : '❌ Invalid query. This assistant is limited to Disaster Management references (SOP MKN 20), PPS, Alerts, and Rescue Operations.';
        } else {
          answer = raw.trim();
        }
      } else {
        // No API key — use local knowledge base
        answer = relevant ? ctx : (isMs ? '❌ Akses Disekat. Unit ini dikhaskan untuk Prosedur Operasi Standard (SOP) pengurusan bencana kerajaan sahaja.' : '❌ Access Restricted. This unit is dedicated to government disaster management Standard Operating Procedures (SOP) only.');
      }
    } catch (_) {
      answer = relevant ? ctx : 'Amaran: Sambungan pelayan tidak stabil. Paparan SOP offline: \n\n'
          'SOP 1: Patuhi rantaian arahan PKOB/PKON.\nSOP 2: Utamakan kes-kes kecemasan/medikal.';
    }

    final isOffTopic = answer.startsWith('❌') || answer.startsWith('❌ Access');
    if (mounted) {
      setState(() {
        _messages.add((isUser: false, text: answer, isOffTopic: isOffTopic));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Slightly darker grey for gov command feel
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F), // Dark Gov Blue
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(50),
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isMs ? 'Pembantu AI Arahan' : 'Command AI Assistant',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              Text(isMs ? 'MKN No. 20 • Protokol Selamat' : 'MKN No. 20 • Secured Protocol',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        // Subtle warning bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: const Color(0xFFFEF9C3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 12, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text(isMs ? "TERHAD KEPADA OPERASI KERAJAAN SAHAJA" : "RESTRICTED TO GOVERNMENT OPERATIONS ONLY",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309), letterSpacing: 0.5)),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) return const _TypingIndicator();
              final m = _messages[i];
              return m.isUser
                  ? _UserBubble(text: m.text)
                  : _AIBubble(text: m.text, isOffTopic: m.isOffTopic);
            },
          ),
        ),

        // Quick Command Chips
        if (_messages.length <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                if (isMs) ...[
                  'Tahap Amaran JPS', 'SOP Pembukaan PPS',
                  'Keselamatan Terowong SMART', 'Prosedur Penipuan BWI',
                  'Zon Merah / Protokol Luar Talian', 'Prosedur MEDEVAC Udara'
                ] else ...[
                  'JPS Alert Levels', 'PPS Opening SOP',
                  'SMART Tunnel Safety', 'BWI Fraud Procedures',
                  'Red Zone / Offline Protocol', 'Air MEDEVAC Procedures'
                ]
              ].map((s) => GestureDetector(
                onTap: () { _ctrl.text = s; _send(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 2, offset: const Offset(0, 1))],
                      borderRadius: BorderRadius.circular(6)), // Square rigid edges for gov
                  child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ),

        _buildInput(isMs),
      ]),
    );
  }

  Widget _buildInput(bool isMs) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -4))]),
    child: Row(children: [
      Expanded(child: TextField(
        controller: _ctrl,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: isMs ? 'Masukkan arahan, pertanyaan SOP, atau senario...' : 'Enter command, SOP query, or scenario...',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          filled: true, fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) => _send(),
      )),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: _loading ? null : _send,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _loading ? Colors.grey : const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}

// ── Bubbles ───────────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F), // Dark Gov theme
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12), topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12), bottomRight: Radius.circular(2),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)),
    ),
  );
}

class _AIBubble extends StatelessWidget {
  final String text;
  final bool isOffTopic;
  const _AIBubble({required this.text, this.isOffTopic = false});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
      decoration: BoxDecoration(
        color: isOffTopic ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2), topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: isOffTopic ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isOffTopic) ...[
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
        ] else ...[
          const Icon(Icons.shield_outlined, color: Color(0xFF1E3A5F), size: 18),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(text,
            style: TextStyle(
              color: isOffTopic ? const Color(0xFF991B1B) : const Color(0xFF1F2937),
              fontSize: 14, height: 1.5,
            ))),
      ]),
    ),
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A5F))),
        const SizedBox(width: 12),
        Text(Provider.of<LocaleProvider>(context).locale.languageCode == 'ms' ? 'Mengakses Pangkalan Data...' : 'Accessing Database...', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ]),
    ),
  );
}
