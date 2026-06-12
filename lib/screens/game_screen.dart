import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class NarrativeEntry {
  final String text;
  final bool isPlayer;
  // Visualizer — pouze pro narrator bubliny přicházející z backendu
  final String? eventId;
  final bool visualizerAvailable;
  NarrativeEntry({
    required this.text,
    required this.isPlayer,
    this.eventId,
    this.visualizerAvailable = false,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _api = ApiService();
  final _actionController = TextEditingController();
  final _scrollController = ScrollController();
  final List<NarrativeEntry> _entries = [];

  bool _sending = false;
  bool _loadingHistory = true;
  bool _showTypingIndicator = false;

  // Typewriter state — pouze pro nové zprávy z backendu (ne historii)
  String? _typewriterFull;
  String  _typewriterVisible = '';
  Timer?  _typewriterTimer;

  // Visualizer state — event_id → stav ('loading' | 'done' | 'error')
  // image_url uložena v _visionImages
  final Map<String, String>  _visionState  = {};  // eventId → 'loading'|'done'|'error'
  final Map<String, String>  _visionImages = {};  // eventId → image_url

  // Pending visualizer po dokončení typewriteru
  String? _pendingVisualizerEventId;
  bool    _debugForceVisualizer = true; // TODO: odstranit po Phase 2B

  String? _campaignId;

  // Hardcoded pro MVP-0 — Phase 2 načte ze server dat
  static const _locationName  = 'Crossroads Inn';
  static const _worldInstance = 'Svět II';
  static const _tokens        = 0;
  static const _visionCredits = 0;

  @override
  void initState() {
    super.initState();
    // Route argumenty nejsou dostupné v initState — čekáme na první frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint('[GameScreen] initState args: $args');
      if (args is Map<String, dynamic>) {
        _campaignId = args['id']?.toString() ?? args['campaign_id']?.toString();
      }
      debugPrint('[GameScreen] campaignId resolved: $_campaignId');
      if (_campaignId != null) {
        _loadHistory(_campaignId!);
      } else {
        if (mounted) setState(() => _loadingHistory = false);
      }
    });
  }

  Future<void> _loadHistory(String campaignId) async {
    debugPrint('[GameScreen] _loadHistory START campaignId=$campaignId');
    try {
      final history = await _api.getCampaignHistory(campaignId);
      debugPrint('[GameScreen] history response: ${history.length} items');
      if (!mounted) return;
      final entries = <NarrativeEntry>[];
      for (final item in history) {
        final intent    = item['raw_intent']?.toString() ?? '';
        final narrative = item['narrative']?.toString() ?? '';
        debugPrint('[GameScreen] item tick=${item['tick']} intent="$intent" narrative="${narrative.length > 40 ? narrative.substring(0, 40) : narrative}..."');
        if (intent.isNotEmpty)    entries.add(NarrativeEntry(text: intent,    isPlayer: true));
        if (narrative.isNotEmpty) entries.add(NarrativeEntry(text: narrative, isPlayer: false));
      }
      debugPrint('[GameScreen] entries built: ${entries.length}');
      setState(() => _entries.addAll(entries));
      _scrollToBottom();
    } catch (e, st) {
      debugPrint('[GameScreen] _loadHistory ERROR: $e\n$st');
      // Tiché selhání — hra pokračuje bez historie.
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _actionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTypewriter(String fullText, {String? eventId, bool visualizerAvailable = false}) {
    _typewriterFull    = fullText;
    _typewriterVisible = '';
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final current = _typewriterVisible.length;
      final next    = (current + 1).clamp(0, fullText.length);
      setState(() => _typewriterVisible = fullText.substring(0, next));
      _scrollToBottom();
      if (next >= fullText.length) {
        timer.cancel();
        setState(() {
          _entries.add(NarrativeEntry(
            text:                 fullText,
            isPlayer:             false,
            eventId:              eventId,
            visualizerAvailable:  visualizerAvailable,
          ));
          _typewriterFull    = null;
          _typewriterVisible = '';
        });
      }
    });
  }

  Future<void> _requestVision(String eventId) async {
    if (_visionState[eventId] != null) return; // již načítáme nebo hotovo
    setState(() => _visionState[eventId] = 'loading');
    _scrollToBottom();
    try {
      final result = await _api.generateVision(eventId);
      final imageUrl = result['image_url']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _visionImages[eventId] = imageUrl;
        _visionState[eventId]  = 'done';
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _visionState[eventId] = 'error');
      _snack('Vision generation failed');
    }
  }

  Future<void> _sendAction() async {
    final text = _actionController.text.trim();
    if (text.isEmpty || _sending || _campaignId == null) return;

    setState(() {
      _entries.add(NarrativeEntry(text: text, isPlayer: true));
      _sending = true;
      _showTypingIndicator = true;
    });
    _actionController.clear();
    _scrollToBottom();

    try {
      final result = await _api.sendAction(campaignId: _campaignId!, action: text);
      final narrative  = result['narrative'] as String? ?? result['response'] as String? ?? '';
      final eventId    = result['event_id']?.toString();
      final vizAvail   = (result['visualizer_available'] as bool? ?? false)
                         || _debugForceVisualizer;  // TODO: odstranit _debugForceVisualizer
      if (mounted) {
        setState(() {
          _showTypingIndicator = false;
          if (vizAvail && eventId != null) _pendingVisualizerEventId = eventId;
        });
        _startTypewriter(narrative, eventId: eventId, visualizerAvailable: vizAvail);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showTypingIndicator = false;
          _entries.add(NarrativeEntry(text: 'Error: $e', isPlayer: false));
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
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

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Color(0xFFE8D5B7))),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A2A4E)),
        ),
      ),
    );
  }

  void _showCampaignDetail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CampaignDetailSheet(campaignId: _campaignId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _GameTopBar(
          locationName:  _locationName,
          worldInstance: _worldInstance,
          tokens:        _tokens,
          visionCredits: _visionCredits,
          onLocationTap: _showCampaignDetail,
          onCharacterTap: () => Navigator.pushNamed(
            context,
            '/character',
            arguments: {'campaign_id': _campaignId},
          ),
          onInventoryTap: () => _snack('Inventory — coming soon'),
          onShopTap:      () => _snack('Shop — coming soon'),
          onCurrencyTap:  () => _snack('Vision Tokens · Vision Credits'),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B1A1A)))
                : (_entries.isEmpty && _typewriterFull == null && !_showTypingIndicator)
                    ? const Center(
                        child: Text(
                          'The world awaits your first action...',
                          style: TextStyle(
                            color: Color(0xFF6A5A4A),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        // entries + volitelná typewriter bublina + volitelný typing indicator
                        itemCount: _entries.length
                            + (_typewriterFull != null ? 1 : 0)
                            + (_showTypingIndicator ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < _entries.length) {
                            final entry = _entries[i];
                            return _NarrativeCard(
                              entry:        entry,
                              visionState:  entry.eventId != null ? _visionState[entry.eventId!] : null,
                              visionImage:  entry.eventId != null ? _visionImages[entry.eventId!] : null,
                              onVisionTap:  entry.eventId != null ? () => _requestVision(entry.eventId!) : null,
                            );
                          }
                          final offset = i - _entries.length;
                          if (_typewriterFull != null && offset == 0) {
                            return _TypewriterCard(text: _typewriterVisible);
                          }
                          return const _TypingIndicatorCard();
                        },
                      ),
          ),
          if (_sending)
            const LinearProgressIndicator(
              color: Color(0xFF8B1A1A),
              backgroundColor: Color(0xFF1A1A2E),
            ),
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFF1A1A2E),
              padding: EdgeInsets.fromLTRB(
                12, 12, 12,
                12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _actionController,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'What do you do?',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFC8A96E)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF7A6A8A), width: 2),
                        ),
                      ),
                      style: const TextStyle(color: Color(0xFFD4C5A9)),
                      onSubmitted: (_) => _sendAction(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _sendAction,
                    icon: const Icon(Icons.send),
                    color: const Color(0xFF8B1A1A),
                    iconSize: 28,
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _GameTopBar extends StatelessWidget {
  final String locationName;
  final String worldInstance;
  final int tokens;
  final int visionCredits;
  final VoidCallback onLocationTap;
  final VoidCallback onCharacterTap;
  final VoidCallback onInventoryTap;
  final VoidCallback onShopTap;
  final VoidCallback onCurrencyTap;

  const _GameTopBar({
    required this.locationName,
    required this.worldInstance,
    required this.tokens,
    required this.visionCredits,
    required this.onLocationTap,
    required this.onCharacterTap,
    required this.onInventoryTap,
    required this.onShopTap,
    required this.onCurrencyTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: EdgeInsets.fromLTRB(8, top, 8, 0),
      height: 64 + top,
      child: Row(
        children: [
          // ── Vlevo: character + inventory ──────────────────────────────────
          _IconBtn(asset: 'assets/icons/char_sheet.png',  onTap: onCharacterTap, tooltip: 'Character'),
          _IconBtn(asset: 'assets/icons/inventory.png',   onTap: onInventoryTap, tooltip: 'Inventory'),

          // ── Střed: lokace + svět ──────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onLocationTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          locationName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE8D5B7),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6A5A4A), size: 16),
                    ],
                  ),
                  Text(
                    worldInstance,
                    style: const TextStyle(color: Color(0xFF6A5A4A), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // ── Vpravo: currency pill + shop ──────────────────────────────────
          _CurrencyPill(tokens: tokens, visionCredits: visionCredits, onTap: onCurrencyTap),
          const SizedBox(width: 4),
          _IconBtn(asset: 'assets/icons/shop.png', onTap: onShopTap, tooltip: 'Shop'),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({required this.asset, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Image.asset(
              asset,
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Color(0xFF4A4A6A), size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  final int tokens;
  final int visionCredits;
  final VoidCallback onTap;

  const _CurrencyPill({required this.tokens, required this.visionCredits, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A4E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrencyItem(asset: 'assets/icons/token.png',         value: tokens),
          const SizedBox(width: 2),
          Container(width: 1, height: 14, color: const Color(0xFF2A2A4E)),
          const SizedBox(width: 2),
          _CurrencyItem(asset: 'assets/icons/vision_credit.png', value: visionCredits),
        ],
      ),
      ),
    );
  }
}

class _CurrencyItem extends StatelessWidget {
  final String asset;
  final int value;

  const _CurrencyItem({required this.asset, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          asset,
          width: 14,
          height: 14,
          errorBuilder: (_, __, ___) => const Icon(Icons.circle, color: Color(0xFF4A4A6A), size: 12),
        ),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: const TextStyle(color: Color(0xFFD4C5A9), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Campaign detail bottom sheet
// ---------------------------------------------------------------------------

class _CampaignDetailSheet extends StatelessWidget {
  final String? campaignId;
  const _CampaignDetailSheet({required this.campaignId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A4E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'KAMPAŇ',
            style: TextStyle(color: Color(0xFF8B1A1A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const Divider(color: Color(0xFF2A2A4E), height: 16),
          _DetailRow(label: 'Šablona',          value: 'Adventurer'),
          _DetailRow(label: 'Svět',              value: 'II'),
          _DetailRow(label: 'Aktuální lokace',   value: 'Crossroads Inn'),
          _DetailRow(label: 'Poslední uložení',  value: '—'),   // TODO: Phase 2 — timestamp z campaign
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9A8A74), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFFE8D5B7), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator  (animované tečky — čeká se na odpověď backendu)
// ---------------------------------------------------------------------------

class _TypingIndicatorCard extends StatefulWidget {
  const _TypingIndicatorCard();

  @override
  State<_TypingIndicatorCard> createState() => _TypingIndicatorCardState();
}

class _TypingIndicatorCardState extends State<_TypingIndicatorCard> {
  static const _frames = ['.', '..', '...'];
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % _frames.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Text(
        _frames[_frame],
        style: const TextStyle(color: Color(0xFF6A5A4A), fontSize: 18, letterSpacing: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typewriter card  (narativ se postupně odkrývá)
// ---------------------------------------------------------------------------

class _TypewriterCard extends StatelessWidget {
  final String text;
  const _TypewriterCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFE8D5B7), fontSize: 15, height: 1.6),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Narrative cards
// ---------------------------------------------------------------------------

class _NarrativeCard extends StatelessWidget {
  final NarrativeEntry entry;
  final String?       visionState;   // null | 'loading' | 'done' | 'error'
  final String?       visionImage;   // image_url pokud done
  final VoidCallback? onVisionTap;

  const _NarrativeCard({
    required this.entry,
    this.visionState,
    this.visionImage,
    this.onVisionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entry.isPlayer) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1A3E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4A2A5A)),
          ),
          child: Text(
            entry.text,
            style: const TextStyle(color: Color(0xFFD4C5A9), fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12121E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A3E)),
          ),
          child: Text(
            entry.text,
            style: const TextStyle(color: Color(0xFFE8D5B7), fontSize: 15, height: 1.6),
          ),
        ),
        // Vision image (pokud vygenerován)
        if (visionState == 'done' && visionImage != null)
          _VisionImage(imageUrl: visionImage!),
        // Loading indicator
        if (visionState == 'loading')
          const _VisionLoadingCard(),
        // Visualizer button
        if (entry.visualizerAvailable && visionState == null)
          _VisionButton(onTap: onVisionTap),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Visualizer widgets
// ---------------------------------------------------------------------------

class _VisionButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _VisionButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC8A96E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/vision_credit.png',
              width: 16, height: 16,
              errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, color: Color(0xFFC8A96E), size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Preserve this moment as a vision?',
              style: TextStyle(color: Color(0xFFC8A96E), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisionLoadingCard extends StatelessWidget {
  const _VisionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A4E)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(color: Color(0xFFC8A96E), strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Weaving the vision...', style: TextStyle(color: Color(0xFF6A5A4A), fontSize: 12)),
        ],
      ),
    );
  }
}

class _VisionImage extends StatelessWidget {
  final String imageUrl;
  const _VisionImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC8A96E)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFC8A96E))),
              ),
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 80,
          child: Center(
            child: Text('Image unavailable', style: TextStyle(color: Color(0xFF6A5A4A))),
          ),
        ),
      ),
    );
  }
}
