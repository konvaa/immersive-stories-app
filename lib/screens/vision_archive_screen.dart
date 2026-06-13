import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VisionArchiveScreen extends StatefulWidget {
  const VisionArchiveScreen({super.key});

  @override
  State<VisionArchiveScreen> createState() => _VisionArchiveScreenState();
}

class _VisionArchiveScreenState extends State<VisionArchiveScreen> {
  final _api = ApiService();

  String? _campaignId;
  bool    _loading   = true;
  String? _error;
  List<Map<String, dynamic>> _visuals = [];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _campaignId = args['campaign_id']?.toString();
    }
    if (_campaignId != null) {
      _loadVisuals(_campaignId!);
    } else {
      setState(() { _loading = false; _error = 'Kampaň nenalezena.'; });
    }
  }

  Future<void> _loadVisuals(String campaignId) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.getCampaignVisuals(campaignId);
      if (!mounted) return;
      setState(() {
        _visuals = List<Map<String, dynamic>>.from(result);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // 404 = endpoint zatím neexistuje → placeholder
      if (e.statusCode == 404 || e.statusCode == 405) {
        setState(() { _visuals = []; _loading = false; });
      } else {
        setState(() { _error = e.message; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _visuals = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE8D5B7)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Vision Archive',
          style: TextStyle(
            color: Color(0xFFC8A96E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Color(0xFF2A2A4E), height: 1),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B1A1A)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6A5A4A), fontSize: 14),
          ),
        ),
      );
    }

    if (_visuals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/gallery.png',
              width: 48, height: 48,
              color: const Color(0xFF2A2A4E),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF2A2A4E),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No visions yet',
              style: TextStyle(
                color: Color(0xFF6A5A4A),
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preserve moments during your journey\nto build your Vision Archive.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4A4A6A), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: _visuals.length,
      itemBuilder: (context, i) {
        final visual   = _visuals[i];
        final imageUrl = visual['image_url']?.toString() ?? visual['original_image_url']?.toString() ?? '';
        return _VisionTile(imageUrl: imageUrl, visual: visual);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Grid tile
// ---------------------------------------------------------------------------

class _VisionTile extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic> visual;

  const _VisionTile({required this.imageUrl, required this.visual});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2A4E)),
          color: const Color(0xFF12121E),
        ),
        clipBehavior: Clip.hardEdge,
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFC8A96E), strokeWidth: 2,
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Color(0xFF4A4A6A), size: 32),
                ),
              )
            : const Center(
                child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF4A4A6A), size: 32),
              ),
      ),
    );
  }

  void _showFullscreen(BuildContext context) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 200,
                child: Center(
                  child: Text('Image unavailable', style: TextStyle(color: Color(0xFF6A5A4A))),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
