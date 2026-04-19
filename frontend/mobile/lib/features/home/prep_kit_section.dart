import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _KitItem {
  final String id;
  final TextEditingController ctrl;
  final FocusNode focus;
  bool done;

  _KitItem({required String text, this.done = false})
      : id = UniqueKey().toString(),
        ctrl = TextEditingController(text: text),
        focus = FocusNode();

  void dispose() {
    ctrl.dispose();
    focus.dispose();
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class PrepKitSection extends StatefulWidget {
  final String userName;
  const PrepKitSection({super.key, required this.userName});
  @override
  State<PrepKitSection> createState() => _PrepKitSectionState();
}

class _PrepKitSectionState extends State<PrepKitSection> {
  late final List<_KitItem> _items;

  static const _defaults = [
    ('Flashlight & heavy-duty batteries', false),
    ('Powerbank (fully charged)', true),
    ('Important documents (IC, Insurance)', false),
    ('Emergency food (3-day supply)', false),
    ('Clean water — 3L per person per day', false),
    ('First aid kit', false),
    ('Household profile updated in FloodSense', true),
  ];

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _items = [for (final (t, d) in _defaults) _KitItem(text: t, done: d)];
    for (final item in _items) { _attachFocusListener(item); }
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('prep_kits').doc(widget.userName).get();
      if (doc.exists && doc.data() != null) {
        final list = doc.data()!['items'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          if (mounted) {
            setState(() {
              for (final item in _items) { item.dispose(); }
              _items.clear();
              for (final map in list) {
                final m = map as Map<String, dynamic>;
                final item = _KitItem(text: m['t'] ?? '', done: m['d'] ?? false);
                _attachFocusListener(item);
                _items.add(item);
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _triggerSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final list = _items.where((i) => i.ctrl.text.isNotEmpty).map((i) => {
        't': i.ctrl.text,
        'd': i.done,
      }).toList();
      FirebaseFirestore.instance.collection('prep_kits').doc(widget.userName).set({'items': list});
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (final item in _items) { item.dispose(); }
    super.dispose();
  }

  void _attachFocusListener(_KitItem item) {
    item.focus.addListener(() {
      if (!mounted) return;
      // AUTO-DELETE: when focus leaves an empty item, remove it
      if (!item.focus.hasFocus && item.ctrl.text.isEmpty) {
        final idx = _items.indexOf(item);
        if (idx != -1) {
          // Small delay so tap-on-checkbox doesn't misfire
          Future.delayed(const Duration(milliseconds: 80), () {
            if (!mounted) return;
            if (item.ctrl.text.isEmpty && !item.focus.hasFocus) {
              item.dispose();
              setState(() => _items.remove(item));
              _triggerSave();
            }
          });
        }
      }
    });
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void _insertAt(int index, {String text = ''}) {
    final item = _KitItem(text: text);
    _attachFocusListener(item);
    setState(() => _items.insert(index, item));
    _triggerSave();
    WidgetsBinding.instance.addPostFrameCallback((_) => item.focus.requestFocus());
  }

  void _remove(_KitItem item) {
    final idx = _items.indexOf(item);
    if (idx == -1) return;
    _KitItem? next;
    if (_items.length > 1) next = _items[idx > 0 ? idx - 1 : 1];
    item.dispose();
    setState(() => _items.remove(item));
    _triggerSave();
    WidgetsBinding.instance.addPostFrameCallback((_) => next?.focus.requestFocus());
  }

  // Enter = new bullet; Enter on empty = dismiss keyboard (auto-delete fires via focus listener)
  void _onSubmitted(_KitItem item) {
    if (item.ctrl.text.isEmpty) {
      FocusScope.of(context).unfocus();
    } else {
      final idx = _items.indexOf(item);
      _insertAt(idx + 1);
    }
  }

  // Backspace on empty line = explicit remove
  bool _handleBackspace(_KitItem item, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        item.ctrl.text.isEmpty &&
        _items.length > 1) {
      _remove(item);
      return true;
    }
    return false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final completed = _items.where((i) => i.done).length;
    final total = _items.length;
    final allDone = total > 0 && completed == total;

    // Uncompleted first, then completed
    final sorted = [
      ..._items.where((i) => !i.done),
      ..._items.where((i) => i.done),
    ];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            const Icon(Icons.checklist_outlined, color: AppTheme.govBlue, size: 20),
            const SizedBox(width: 8),
            const Text('Preparedness Kit',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: allDone ? AppTheme.hopeLight : AppTheme.govBlueLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$completed/$total',
                  style: TextStyle(
                      color: allDone ? AppTheme.hope : AppTheme.govBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation(allDone ? AppTheme.hope : AppTheme.govBlue),
              minHeight: 6,
            ),
          ),
          if (allDone)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('All packed! 🎒 You are ready.',
                  style: TextStyle(color: AppTheme.hope, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 10),

          // Items
          ...sorted.map((item) => _KitTile(
                key: ValueKey(item.id),
                item: item,
                onToggle: () {
                  HapticFeedback.lightImpact();
                  setState(() => item.done = !item.done);
                  _triggerSave();
                  FocusScope.of(context).unfocus();
                },
                onSubmitted: () => _onSubmitted(item),
                onBackspace: (e) => _handleBackspace(item, e),
                onDelete: () {
                  HapticFeedback.mediumImpact();
                  _remove(item);
                },
                onChanged: (_) {
                  setState(() {});
                  _triggerSave();
                },
              )),

          // + Add item
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _insertAt(_items.length),
            child: const Padding(
              padding: EdgeInsets.only(top: 4, left: 4, bottom: 2),
              child: Row(children: [
                Icon(Icons.add, color: AppTheme.textMuted, size: 18),
                SizedBox(width: 8),
                Text('Add item / Tambah barang',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Individual tile ───────────────────────────────────────────────────────────

class _KitTile extends StatefulWidget {
  final _KitItem item;
  final VoidCallback onToggle;
  final VoidCallback onSubmitted;
  final bool Function(KeyEvent) onBackspace;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  const _KitTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onSubmitted,
    required this.onBackspace,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_KitTile> createState() => _KitTileState();
}

class _KitTileState extends State<_KitTile> {
  bool _revealDelete = false;
  double _dragStart = 0;

  void _onDragStart(DragStartDetails d) => _dragStart = d.globalPosition.dx;

  void _onDragUpdate(DragUpdateDetails d, double screenWidth) {
    final delta = _dragStart - d.globalPosition.dx; // positive = left swipe
    if (delta > screenWidth * 0.15 && !_revealDelete) {
      setState(() => _revealDelete = true);
    } else if (delta < -screenWidth * 0.08 && _revealDelete) {
      setState(() => _revealDelete = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: (d) => _onDragUpdate(d, screenWidth),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          // Main content
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Circle toggle — tap immediately toggles, no focus box
              GestureDetector(
                onTap: widget.onToggle,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    key: ValueKey(widget.item.done),
                    widget.item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: widget.item.done ? AppTheme.hope : AppTheme.govBlue,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Inline text — no border, no selection box
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: widget.onBackspace,
                  child: TextField(
                    controller: widget.item.ctrl,
                    focusNode: widget.item.focus,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => widget.onSubmitted(),
                    onChanged: widget.onChanged,
                    style: TextStyle(
                      color: widget.item.done ? const Color(0xFFAAAAAA) : Colors.black,
                      decoration: widget.item.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: const Color(0xFFAAAAAA),
                      decorationThickness: 2,
                      fontSize: 14,
                      fontWeight: widget.item.done ? FontWeight.w400 : FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ]),
          ),

          // Swipe-revealed Red Trash Can
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _revealDelete ? 52 : 0,
            curve: Curves.easeOut,
            child: _revealDelete
                ? GestureDetector(
                    onTap: () {
                      setState(() => _revealDelete = false);
                      widget.onDelete();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.emergency,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.delete_outline, color: Colors.white, size: 20),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}
