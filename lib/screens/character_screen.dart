import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final campaignId = args?['campaign_id']?.toString();
    if (campaignId != null) {
      _load(campaignId);
    } else {
      setState(() { _loading = false; _error = 'Chybí campaign_id'; });
    }
  }

  Future<void> _load(String campaignId) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.loadCampaign(campaignId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Character'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B1A1A)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))))
              : _data == null
                  ? const Center(child: Text('No data', style: TextStyle(color: Color(0xFF6A5A4A))))
                  : _Body(data: _data!),
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    final snapshot = data['snapshot_json'] as Map<String, dynamic>? ?? {};
    final ps = snapshot['player_state'] as Map<String, dynamic>? ?? {};
    final npcs = data['npcs'] as List<dynamic>? ?? [];
    final flags = ps['flags'] as List<dynamic>? ?? [];

    final hp    = (ps['hp']     as num?)?.toInt() ?? 0;
    final maxHp = (ps['max_hp'] as num?)?.toInt() ?? 100;
    final gold  = (ps['gold']   as num?)?.toInt() ?? 0;
    final locationId = ps['location_id']?.toString() ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Vitals',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HpBar(hp: hp, maxHp: maxHp),
                const SizedBox(height: 14),
                _StatRow(label: 'Gold', value: '$gold ✦', valueColor: const Color(0xFFB8860B)),
                const SizedBox(height: 8),
                _StatRow(label: 'Location', value: locationId),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Flags',
            child: flags.isEmpty
                ? const Text('—', style: TextStyle(color: Color(0xFF6A5A4A), fontStyle: FontStyle.italic))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: flags.map((f) => Chip(
                      label: Text(f.toString(), style: const TextStyle(color: Color(0xFFD4C5A9), fontSize: 12)),
                      backgroundColor: const Color(0xFF16213E),
                      side: const BorderSide(color: Color(0xFF2A2A5A)),
                      padding: EdgeInsets.zero,
                    )).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'NPCs',
            child: npcs.isEmpty
                ? const Text('Nikdo nablízku.', style: TextStyle(color: Color(0xFF6A5A4A), fontStyle: FontStyle.italic))
                : Column(
                    children: npcs.map((n) => _NpcRow(npc: n as Map<String, dynamic>)).toList(),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A4E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8B1A1A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const Divider(color: Color(0xFF2A2A4E), height: 20),
          child,
        ],
      ),
    );
  }
}

class _HpBar extends StatelessWidget {
  final int hp;
  final int maxHp;
  const _HpBar({required this.hp, required this.maxHp});

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final barColor = ratio > 0.5
        ? const Color(0xFF2E8B57)
        : ratio > 0.25
            ? const Color(0xFFB8860B)
            : const Color(0xFF8B1A1A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('HP', style: TextStyle(color: Color(0xFFD4C5A9))),
            Text('$hp / $maxHp', style: const TextStyle(color: Color(0xFFE8D5B7), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0xFF2A2A3E),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatRow({required this.label, required this.value, this.valueColor = const Color(0xFFE8D5B7)});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF9A8A74))),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _NpcRow extends StatelessWidget {
  final Map<String, dynamic> npc;
  const _NpcRow({required this.npc});

  @override
  Widget build(BuildContext context) {
    final name     = npc['name']?.toString()      ?? '?';
    final trust    = (npc['trust']      as num?)?.toInt() ?? 0;
    final fear     = (npc['fear']       as num?)?.toInt() ?? 0;
    final suspicion = (npc['suspicion'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF8B7355)),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(color: Color(0xFFE8D5B7), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _NpcStat(label: 'Trust',      value: trust,     color: const Color(0xFF2E8B57)),
              const SizedBox(width: 16),
              _NpcStat(label: 'Fear',       value: fear,      color: const Color(0xFF8B1A1A)),
              const SizedBox(width: 16),
              _NpcStat(label: 'Suspicion',  value: suspicion, color: const Color(0xFFB8860B)),
            ],
          ),
          const Divider(color: Color(0xFF2A2A4E), height: 16),
        ],
      ),
    );
  }
}

class _NpcStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _NpcStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: const TextStyle(color: Color(0xFF6A5A4A), fontSize: 12)),
        Text('$value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
