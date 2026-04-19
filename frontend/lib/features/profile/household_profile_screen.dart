import 'package:flutter/material.dart';
import 'profile_repository.dart';
import 'package:provider/provider.dart';
import '../../core/providers/locale_provider.dart';

class HouseholdProfileScreen extends StatefulWidget {
  const HouseholdProfileScreen({super.key});

  @override
  State<HouseholdProfileScreen> createState() => _HouseholdProfileScreenState();
}

class _HouseholdProfileScreenState extends State<HouseholdProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  int _householdSize = 1;
  final List<String> _allNeeds = ['wheelchair', 'elderly', 'infant', 'heart_medication', 'dialysis', 'oxygen'];
  final Set<String> _selectedNeeds = {};
  bool _saving = false;
  bool _saved = false;
  final _repo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _repo.loadProfile();
    if (profile != null && mounted) {
      setState(() {
        _nameCtrl.text = profile.fullName;
        _addressCtrl.text = profile.address;
        _householdSize = profile.householdSize;
        _selectedNeeds.addAll(profile.vulnerableGroups);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _repo.saveProfile(HouseholdProfile(
      fullName: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      householdSize: _householdSize,
      vulnerableGroups: _selectedNeeds.toList(),
    ));
    setState(() { _saving = false; _saved = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMalay = Provider.of<LocaleProvider>(context).locale.languageCode == 'ms';
    
    String translateNeed(String need) {
      if (isMalay) {
        switch (need) {
          case 'wheelchair': return 'Kerusi Roda';
          case 'elderly': return 'Warga Emas';
          case 'infant': return 'Bayi';
          case 'heart_medication': return 'Ubat Jantung';
          case 'dialysis': return 'Dialisis';
          case 'oxygen': return 'Oksigen';
        }
      } else {
        switch (need) {
          case 'wheelchair': return 'Wheelchair';
          case 'elderly': return 'Elderly';
          case 'infant': return 'Infant';
          case 'heart_medication': return 'Heart Medication';
          case 'dialysis': return 'Dialysis';
          case 'oxygen': return 'Oxygen';
        }
      }
      return need;
    }

    return Scaffold(
      appBar: AppBar(title: Text(isMalay ? 'Profil Isi Rumah' : 'Household Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _sectionTitle(isMalay ? 'Maklumat Peribadi' : 'Personal Info'),
            const SizedBox(height: 12),
            _field(_nameCtrl, isMalay ? 'Nama Penuh' : 'Full Name', Icons.person, isMalay: isMalay),
            const SizedBox(height: 16),
            _field(_addressCtrl, isMalay ? 'Alamat Rumah' : 'Home Address', Icons.home, maxLines: 2, isMalay: isMalay),
            const SizedBox(height: 24),
            _sectionTitle(isMalay ? 'Bilangan Isi Rumah' : 'Household Size'),
            const SizedBox(height: 12),
            Row(children: [
              IconButton(
                onPressed: () { if (_householdSize > 1) setState(() => _householdSize--); },
                icon: const Icon(Icons.remove_circle_outline),
                color: const Color(0xFFE53935),
              ),
              Text('$_householdSize', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: () => setState(() => _householdSize++),
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFFE53935),
              ),
              Text(isMalay ? ' orang' : ' people', style: const TextStyle(color: Color(0xFF757575))),
            ]),
            const SizedBox(height: 24),
            _sectionTitle(isMalay ? 'Keperluan Khas' : 'Special Needs'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allNeeds.map((need) {
                final selected = _selectedNeeds.contains(need);
                return FilterChip(
                  label: Text(translateNeed(need)),
                  selected: selected,
                  onSelected: (v) => setState(() { v ? _selectedNeeds.add(need) : _selectedNeeds.remove(need); }),
                  selectedColor: const Color(0xFFE53935).withAlpha(50),
                  checkmarkColor: const Color(0xFFE53935),
                  labelStyle: TextStyle(color: selected ? const Color(0xFFE53935) : const Color(0xFF757575)),
                  side: BorderSide(color: selected ? const Color(0xFFE53935) : const Color(0xFF2A2A2A)),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            if (_saved)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00C853)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00C853)),
                  const SizedBox(width: 8),
                  Text(isMalay ? 'Profil disimpan!' : 'Profile saved!', style: const TextStyle(color: Color(0xFF00C853))),
                ]),
              ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isMalay ? 'SIMPAN' : 'SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF757575), letterSpacing: 1.2));

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1, required bool isMalay}) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF757575)),
          filled: true,
          fillColor: const Color(0xFF141414),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53935)),
          ),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? (isMalay ? 'Wajib diisi' : 'Required') : null,
      );
}
