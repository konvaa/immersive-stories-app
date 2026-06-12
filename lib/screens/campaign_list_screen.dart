import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});

  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen> {
  final _api = ApiService();
  List<dynamic> _campaigns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() { _loading = true; _error = null; });
    try {
      final campaigns = await _api.listCampaigns();
      setState(() => _campaigns = campaigns);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCampaign(dynamic campaign) async {
    final campaignId = campaign['campaign_id']?.toString();
    if (campaignId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Smazat kampaň?', style: TextStyle(color: Color(0xFFE8D5B7))),
        content: const Text(
          'Tato akce je nevratná. Kampaň a veškerá herní data budou trvale smazána.',
          style: TextStyle(color: Color(0xFF9A8A74)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zrušit', style: TextStyle(color: Color(0xFF9A8A74))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteCampaign(campaignId);
      if (mounted) _loadCampaigns();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: const Color(0xFF8B1A1A)),
        );
      }
    }
  }

  Future<void> _newCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _NewCampaignDialog(),
    );

    if (confirmed == true) {
      try {
        final result = await _api.createCampaign(template: 'adventurer');
        if (mounted) {
          Navigator.pushNamed(context, '/game', arguments: result);
          _loadCampaigns();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFF8B1A1A)),
          );
        }
      }
    }
  }

  void _openCampaign(dynamic campaign) {
    Navigator.pushNamed(context, '/game', arguments: campaign);
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B1A1A)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadCampaigns, child: const Text('Retry')),
                    ],
                  ),
                )
              : _campaigns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.book_outlined, size: 64, color: Color(0xFF4A4A6A)),
                          const SizedBox(height: 16),
                          const Text(
                            'No campaigns yet.\nBegin your first adventure.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF8B7355), fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _newCampaign,
                            icon: const Icon(Icons.add),
                            label: const Text('New Campaign'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCampaigns,
                      color: const Color(0xFF8B1A1A),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _campaigns.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = _campaigns[i];
                          return Dismissible(
                            key: ValueKey(c['campaign_id']),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              await _deleteCampaign(c);
                              return false; // reload řeší _loadCampaigns, ne Dismissible
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B1A1A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            child: ListTile(
                              tileColor: const Color(0xFF1A1A2E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              leading: const Icon(Icons.book, color: Color(0xFF8B1A1A)),
                              title: Text(
                                c['template'] ?? 'Campaign ${c['campaign_id']}',
                                style: const TextStyle(color: Color(0xFFE8D5B7)),
                              ),
                              subtitle: Text(
                                c['created_at'] ?? '',
                                style: const TextStyle(color: Color(0xFF8B7355)),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Color(0xFF4A4A6A)),
                              onTap: () => _openCampaign(c),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _campaigns.isNotEmpty
          ? FloatingActionButton(
              onPressed: _newCampaign,
              backgroundColor: const Color(0xFF8B1A1A),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// New Campaign Dialog
// ---------------------------------------------------------------------------

class _NewCampaignDialog extends StatefulWidget {
  const _NewCampaignDialog();

  @override
  State<_NewCampaignDialog> createState() => _NewCampaignDialogState();
}

class _NewCampaignDialogState extends State<_NewCampaignDialog> {
  // Pro MVP-0 je vybrána jediná šablona automaticky.
  static const _templates = [
    _TemplateOption(
      id: 'adventurer',
      title: 'Adventurer',
      subtitle: 'Crossroads Inn',
      description: 'Začínáš jako dobrodružný cizinec v Crossroads Inn. '
          'Hospodský a Sheriff tě pozorují. Co uděláš jako první?',
      icon: Icons.local_bar,
    ),
  ];

  String _selected = 'adventurer';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF12121E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NEW CAMPAIGN',
              style: TextStyle(
                color: Color(0xFF8B1A1A),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Vyber šablonu světa',
              style: TextStyle(color: Color(0xFF9A8A74), fontSize: 13),
            ),
            const SizedBox(height: 16),
            ..._templates.map((t) => _TemplateTile(
              option: t,
              selected: _selected == t.id,
              onTap: () => setState(() => _selected = t.id),
            )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Zrušit', style: TextStyle(color: Color(0xFF9A8A74))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1A1A),
                    foregroundColor: const Color(0xFFE8D5B7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Začít dobrodružství'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateOption {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  const _TemplateOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
  });
}

class _TemplateTile extends StatelessWidget {
  final _TemplateOption option;
  final bool selected;
  final VoidCallback onTap;
  const _TemplateTile({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E0A0A) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF8B1A1A) : const Color(0xFF2A2A4E),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF3A0A0A) : const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(option.icon, color: selected ? const Color(0xFF8B1A1A) : const Color(0xFF4A4A6A), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title, style: const TextStyle(color: Color(0xFFE8D5B7), fontWeight: FontWeight.bold)),
                  Text(option.subtitle, style: const TextStyle(color: Color(0xFF8B7355), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(option.description, style: const TextStyle(color: Color(0xFF6A5A4A), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: Color(0xFF8B1A1A), size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
