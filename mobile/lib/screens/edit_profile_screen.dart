import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/brand_button.dart';
import '../widgets/user_avatar.dart';

/// Sentinel for the "leave the photo untouched" vs. "explicitly clear it"
/// distinction on save — see the matching one in auth_service.dart (privacy
/// is per-file in Dart, so this file needs its own).
const _unset = Object();

/// Edit name and profile photo — the things people expect to be able to
/// change about themselves that the old Account screen had no way to touch
/// at all. Phone number is shown but not editable here: changing it would
/// mean re-verifying a new number by OTP, a different flow entirely.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  String? _photoDataUri;
  bool _photoChanged = false;
  bool _saving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _photoDataUri = user?.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final action = await _showPhotoSourceSheet(context, hasExistingPhoto: _photoDataUri != null);
    if (action == null) return;

    if (action == _PhotoAction.remove) {
      setState(() {
        _photoDataUri = null;
        _photoChanged = true;
      });
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
      // Downscaled and compressed client-side before it ever becomes a
      // base64 string — this goes straight into a Postgres TEXT column
      // with no resizing on the backend, so an uncompressed photo would
      // bloat that row for no visual benefit at avatar size.
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _photoDataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _photoChanged = true;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    setState(() => _validationError = null);
    if (name.isEmpty) {
      setState(() => _validationError = 'Add your name.');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthService>().updateProfile(
            displayName: name,
            photoUrl: _photoChanged ? _photoDataUri : _unset,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingMd, kSpacingLg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.arrow_back, color: Colors.black, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpacingSm),
                        const Text(
                          'Edit profile',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: _choosePhoto,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                    name: _nameController.text.isEmpty
                                        ? (user?.displayName ?? '')
                                        : _nameController.text,
                                    seed: user?.id ?? '',
                                    photoUrl: _photoDataUri,
                                    radius: 48,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: kBrandPurple,
                                        shape: BoxShape.circle,
                                        border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: kSpacingSm),
                          Center(
                            child: TextButton(
                              onPressed: _choosePhoto,
                              child: const Text(
                                'Change photo',
                                style: TextStyle(color: kBrandPurple, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: kSpacingLg),
                          BrandTextField(
                            controller: _nameController,
                            label: 'Your name',
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: kSpacingMd),
                          Container(
                            padding: const EdgeInsets.all(kSpacingMd),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F6FA),
                              borderRadius: BorderRadius.circular(kRadius),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.phone_outlined, color: Colors.black.withOpacity(0.45), size: 18),
                                const SizedBox(width: kSpacingSm),
                                Expanded(
                                  child: Text(
                                    user?.phoneNumber ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  'Not editable',
                                  style: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (_validationError != null) ...[
                            const SizedBox(height: kSpacingMd),
                            Text(
                              _validationError!,
                              style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w500),
                            ),
                          ],
                          const SizedBox(height: kSpacingLg),
                          BrandButton(label: 'Save', loading: _saving, onPressed: _save),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }

Future<_PhotoAction?> _showPhotoSourceSheet(BuildContext context, {required bool hasExistingPhoto}) {
  return showModalBottomSheet<_PhotoAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingLg, kSpacingLg, kSpacingMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: kSpacingMd),
              _SheetAction(
                icon: Icons.photo_camera_outlined,
                label: 'Take a photo',
                onTap: () => Navigator.pop(context, _PhotoAction.camera),
              ),
              _SheetAction(
                icon: Icons.photo_library_outlined,
                label: 'Choose from library',
                onTap: () => Navigator.pop(context, _PhotoAction.gallery),
              ),
              if (hasExistingPhoto)
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove photo',
                  danger: true,
                  onTap: () => Navigator.pop(context, _PhotoAction.remove),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFD32F2F) : Colors.black;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpacingSm),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: kSpacingMd),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
