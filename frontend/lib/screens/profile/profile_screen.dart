import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  int _hostedCount  = 0;
  int _friendCount  = 0;
  bool _uploading   = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.getMe(), ApiClient.getPlans(), ApiClient.getFriends()]);
      final user    = results[0] as Map<String, dynamic>;
      final plans   = results[1] as List<dynamic>;
      final friends = results[2] as List<dynamic>;
      if (mounted) setState(() {
        _user        = user;
        _hostedCount = plans.where((p) => p['is_host'] == true).length;
        _friendCount = friends.length;
      });
    } catch (_) {
      if (mounted) setState(() => _user = {'name': 'User'});
    }
  }

  // ── Photo actions ──────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(ImageSource source) async {
    final xfile = await ImagePicker().pickImage(
        source: source, maxWidth: 1200, imageQuality: 90);
    if (xfile == null || !mounted) return;

    final bytes = await xfile.readAsBytes();
    final cropped = await Navigator.of(context).push<Uint8List>(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => _PhotoCropScreen(imageBytes: bytes),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
    if (cropped == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final path = await ApiClient.uploadProfilePhoto(cropped, 'photo.png');
      if (mounted) setState(() => _user!['profile_photo'] = path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto() async {
    try {
      await ApiClient.deleteProfilePhoto();
      if (mounted) setState(() => _user!['profile_photo'] = null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Dark bottom sheet — Choose library / Take photo / Delete
  void _showDarkSheet({required bool hasPhoto}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 8),
          _darkTile(Icons.photo_library_outlined, 'Choose from library', Colors.white,
              () { Navigator.pop(context); _pickAndUpload(ImageSource.gallery); }),
          if (!kIsWeb) ...[
            _darkDivider(),
            _darkTile(Icons.camera_alt_outlined, 'Take photo', Colors.white,
                () { Navigator.pop(context); _pickAndUpload(ImageSource.camera); }),
          ],
          if (hasPhoto) ...[
            _darkDivider(),
            _darkTile(Icons.delete_outline, 'Delete', AppColors.rose,
                () { Navigator.pop(context); _deletePhoto(); }),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  /// Full-screen photo viewer — returns 'gallery' | 'camera' | 'delete' | null
  Future<void> _openPhotoViewer(String url) async {
    final result = await Navigator.of(context).push<String>(PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _PhotoViewer(url: url),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
    if (!mounted) return;
    if (result == 'gallery') _pickAndUpload(ImageSource.gallery);
    if (result == 'camera')  _pickAndUpload(ImageSource.camera);
    if (result == 'delete')  _deletePhoto();
  }

  void _onAvatarTap() {
    final photo = _user?['profile_photo'] as String?;
    if (photo != null && photo.isNotEmpty) {
      _openPhotoViewer(ApiClient.photoUrl(photo));  // viewer handles options internally
    } else {
      _showDarkSheet(hasPhoto: false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _darkTile(IconData icon, String label, Color color, VoidCallback onTap) =>
    ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontSize: 16)),
      onTap: onTap,
    );

  Widget _darkDivider() =>
    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)));
    }

    final name        = (_user!['name']         as String?) ?? 'User';
    final profession  = (_user!['profession']   as String?) ?? '';
    final hometown    = (_user!['hometown']     as String?) ?? '';
    final currentCity = (_user!['current_city'] as String?) ?? '';
    final photoPath   = _user!['profile_photo'] as String?;
    final trustScore  = ((_user!['trust_score'] as num?) ?? 0.0).toStringAsFixed(1);
    final phoneOk     = _user!['is_phone_verified'] == true;
    final idOk        = _user!['is_id_verified'] == true;
    final bio         = (_user!['bio'] as String?) ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(slivers: [

            // ── Dark hero ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: Container(
              color: AppColors.ink,
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 20, 24, 28),
              child: Column(children: [

                // Avatar
                GestureDetector(
                  onTap: _onAvatarTap,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orange,
                        border: Border.all(color: AppColors.orange, width: 3),
                        boxShadow: [BoxShadow(
                          color: AppColors.orange.withOpacity(0.4),
                          blurRadius: 18, spreadRadius: 2)],
                      ),
                      child: ClipOval(
                        child: photoPath != null && photoPath.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ApiClient.photoUrl(photoPath),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _initial(name))
                          : _initial(name),
                      ),
                    ),
                    if (_uploading)
                      Container(
                        width: 90, height: 90,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.black54),
                        child: const Center(child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))),
                    if (!_uploading)
                      Positioned(bottom: 0, right: 0,
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.orange),
                          child: const Icon(Icons.camera_alt, size: 15, color: Colors.white))),
                  ]),
                ),

                const SizedBox(height: 14),
                Text(name, style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                if (profession.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(profession, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
                if (hometown.isNotEmpty || currentCity.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('From ${hometown.isNotEmpty ? hometown : currentCity} 🧡',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],

                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _stat('⭐', trustScore, 'Score'),
                  _divider(),
                  GestureDetector(
                    onTap: () => context.go('/discover'),
                    child: _stat('🤝', _friendCount.toString(), 'Friends'),
                  ),
                  _divider(),
                  _stat('🚀', _hostedCount.toString(), 'Hosted'),
                ]),
              ]),
            )),

            // ── Body ──────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(delegate: SliverChildListDelegate([
                if (bio.isNotEmpty) ...[
                  _card(children: [
                    const Text('About', style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: AppColors.sub, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Text(bio, style: const TextStyle(
                      fontSize: 14, color: AppColors.ink, height: 1.55)),
                  ]),
                  const SizedBox(height: 8),
                ],
                _card(children: [
                  const Text('VERIFICATION', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.sub, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _vRow('📱', 'Phone number', phoneOk ? 'Verified' : 'Not verified', phoneOk),
                  const Divider(height: 1, color: AppColors.border),
                  _vRow('📧', 'Email address', 'Not set', false),
                  const Divider(height: 1, color: AppColors.border),
                  _vRow('🪪', 'ID check', idOk ? 'Verified' : 'Pending', idOk),
                ]),
                const SizedBox(height: 8),
                ..._menu(context),
              ])),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _menu(BuildContext context) => [
    ('✏️', 'Edit Profile', () => _showEditSheet(context)),
    ('⚙️', 'Settings', null),
    ('🔔', 'Notifications', null),
    ('🔒', 'Privacy & Safety', null),
    ('❓', 'Help & Support', null),
    ('🚪', 'Log out', () async {
      await ApiClient.logout();
      if (context.mounted) context.go('/auth/phone');
    }),
  ].map<Widget>((t) {
    final (icon, label, action) = t;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5)),
      child: ListTile(
        title: Text('$icon  $label', style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
        onTap: action,
      ),
    );
  }).toList();

  void _showEditSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _user!['name'] ?? '');
    final bioCtrl  = TextEditingController(text: _user!['bio'] ?? '');
    final profCtrl = TextEditingController(text: _user!['profession'] ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border,
              borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 16),
          const Text('Edit Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl,
            decoration: const InputDecoration(hintText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: profCtrl,
            decoration: const InputDecoration(hintText: 'Profession')),
          const SizedBox(height: 12),
          TextField(controller: bioCtrl, maxLines: 3,
            decoration: const InputDecoration(hintText: 'Bio')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: saving ? null : () async {
              setModal(() => saving = true);
              try {
                final updated = await ApiClient.updateMe({
                  'name': nameCtrl.text.trim(),
                  'profession': profCtrl.text.trim(),
                  'bio': bioCtrl.text.trim(),
                });
                if (mounted) setState(() => _user = updated);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally { setModal(() => saving = false); }
            },
            child: saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save Changes'),
          )),
        ]),
      )),
    );
  }

  Widget _initial(String name) => Center(child: Text(
    name.isNotEmpty ? name[0].toUpperCase() : 'U',
    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)));

  Widget _stat(String icon, String val, String label) => Expanded(child: Column(children: [
    Text('$icon $val', style: const TextStyle(
      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
  ]));

  Widget _divider() => Container(width: 1, height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white12);

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border, width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));

  Widget _vRow(String icon, String label, String status, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Text('$icon  $label', style: const TextStyle(fontSize: 14)),
      const Spacer(),
      Text(ok ? '✅ $status' : '⏳ $status',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: ok ? AppColors.green : AppColors.amber)),
    ]));
}

// ── Photo crop / move-and-scale screen ───────────────────────────────────────

class _PhotoCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const _PhotoCropScreen({required this.imageBytes});

  @override
  State<_PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<_PhotoCropScreen> {
  final _cropKey  = GlobalKey();
  final _ctrl     = TransformationController();
  bool _processing = false;

  static const double _cropSize = 300.0;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _confirm() async {
    setState(() => _processing = true);
    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !mounted) { Navigator.of(context).pop(); return; }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data  = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(data!.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad   = MediaQuery.of(context).padding;
    final bytes = widget.imageBytes;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [

          // Blurred / dim background
          Positioned.fill(child: Opacity(
            opacity: 0.3,
            child: Image.memory(bytes, fit: BoxFit.cover))),

          // Crop circle — only this is captured by RepaintBoundary
          Center(child: RepaintBoundary(
            key: _cropKey,
            child: SizedBox(
              width: _cropSize, height: _cropSize,
              child: ClipOval(child: InteractiveViewer(
                transformationController: _ctrl,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.memory(bytes,
                  width: _cropSize, height: _cropSize,
                  fit: BoxFit.cover),
              )),
            ),
          )),

          // Dark overlay with circular cutout (decorative — does not affect capture)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _CircleOverlayPainter(radius: _cropSize / 2)))),

          // Top bar
          Positioned(
            top: pad.top, left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop()),
                const Expanded(child: Text('Move and Scale',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
                const SizedBox(width: 48),
              ]),
            ),
          ),

          // "Use Photo" button
          Positioned(
            bottom: pad.bottom + 32, left: 32, right: 32,
            child: ElevatedButton(
              onPressed: _processing ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.orange.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
              child: _processing
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Use Photo',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CircleOverlayPainter extends CustomPainter {
  final double radius;
  const _CircleOverlayPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Dark mask with oval cut-out
    canvas.drawPath(
      Path()
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: center, radius: radius))
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withOpacity(0.55),
    );
    // Circle border
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CircleOverlayPainter old) => old.radius != radius;
}

// ── Full-screen photo viewer ──────────────────────────────────────────────────

class _PhotoViewer extends StatelessWidget {
  final String url;
  const _PhotoViewer({required this.url});

  // Opens the dark edit sheet and returns a result string to the viewer.
  // The viewer then pops with that result so the profile screen can act on it.
  void _showEditSheet(BuildContext viewerCtx) {
    showModalBottomSheet<String>(
      context: viewerCtx,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 8),
          _item(sheetCtx, Icons.photo_library_outlined, 'Choose from library',
              Colors.white, 'gallery', viewerCtx),
          if (!kIsWeb) ...[
            const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
            _item(sheetCtx, Icons.camera_alt_outlined, 'Take photo',
                Colors.white, 'camera', viewerCtx),
          ],
          const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white12),
          _item(sheetCtx, Icons.delete_outline, 'Delete',
              AppColors.rose, 'delete', viewerCtx),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Tapping an item: close the sheet → close the viewer with the result.
  Widget _item(BuildContext sheetCtx, IconData icon, String label,
      Color color, String result, BuildContext viewerCtx) =>
    ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontSize: 16)),
      onTap: () {
        Navigator.pop(sheetCtx);          // 1. close sheet (uses sheet's own context)
        Navigator.pop(viewerCtx, result); // 2. close viewer with result string
      },
    );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [

          // Blurred background
          Positioned.fill(child: Opacity(
              opacity: 0.25,
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover))),

          // Large circle photo
          Center(
            child: SizedBox(
              width: 300, height: 300,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40, spreadRadius: 4)],
                  ),
                  child: ClipOval(child: CachedNetworkImage(
                    imageUrl: url, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[900],
                        child: const Center(child: CircularProgressIndicator(
                            color: Colors.white54, strokeWidth: 2))),
                    errorWidget: (_, __, ___) => Container(color: Colors.grey[900],
                        child: const Icon(Icons.person,
                            size: 80, color: Colors.white24)),
                  ))),

                // Orange edit button
                Positioned(
                  bottom: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => _showEditSheet(context),
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orange,
                        boxShadow: [BoxShadow(
                            color: AppColors.orange.withOpacity(0.4),
                            blurRadius: 12, spreadRadius: 2)],
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 22)),
                  )),
              ])),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context))),
        ]),
      ),
    );
  }
}
