import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/image_upload.dart';
import '../auth/auth_scaffold.dart';

const int _maxGallery = 8;
const int _maxHeadline = 120;
const int _maxBio = 2000;

/// Build or edit the public creator profile: photo, headline, biography and
/// a photo gallery.
///
/// In [apply] mode (opened from "Become an influencer") the profile is
/// required, and saving it also sends the influencer application.
class CreatorProfileScreen extends ConsumerStatefulWidget {
  const CreatorProfileScreen({super.key, this.apply = false});

  final bool apply;

  @override
  ConsumerState<CreatorProfileScreen> createState() =>
      _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends ConsumerState<CreatorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _headline = TextEditingController();
  final _bio = TextEditingController();

  String? _avatar;
  final List<String> _gallery = [];
  bool _uploading = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Start from what is already saved so editing never loses anything.
    ref.read(profileProvider.future).then((p) {
      if (!mounted || _loaded) return;
      setState(() {
        _loaded = true;
        _headline.text = p.headline ?? '';
        _bio.text = p.biography ?? '';
        _avatar = (p.profileImageUrl ?? '').isEmpty ? null : p.profileImageUrl;
        _gallery
          ..clear()
          ..addAll(p.galleryImages);
      });
    }).catchError((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _headline.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => _uploading = true);
    final url = await pickAndUploadImage(context, ref);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _avatar = url;
    });
  }

  Future<void> _addGalleryImage() async {
    if (_gallery.length >= _maxGallery) return;
    setState(() => _uploading = true);
    final url = await pickAndUploadImage(context, ref);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _gallery.add(url);
    });
  }

  String? _validateHeadline(String? v) {
    final s = (v ?? '').trim();
    if (widget.apply && s.length < 3) return 'Add a short headline';
    if (s.length > _maxHeadline) return 'Keep it under $_maxHeadline characters';
    return null;
  }

  String? _validateBio(String? v) {
    final s = (v ?? '').trim();
    if (widget.apply && s.length < 20) {
      return 'Tell people a little about yourself (20+ characters)';
    }
    if (s.length > _maxBio) return 'Keep it under $_maxBio characters';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final pid = ref.read(authProvider).pid;
    if (pid == null) {
      AppToast.error(context, 'Your session expired. Please sign in again.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(apiServiceProvider).updateProfile(pid, {
        'headline': _headline.text.trim(),
        'biography': _bio.text.trim(),
        // Empty string clears the photo; the server only changes what is sent.
        'profileImageUrl': _avatar ?? '',
        'galleryImages': _gallery,
      });
      ref.invalidate(profileProvider);

      if (widget.apply) {
        // The profile is saved first, so a failed application never loses it.
        final message = await ref
            .read(authProvider.notifier)
            .becomeInfluencer();
        // Applying changes the account's roles, which makes the router
        // refresh. Popping in the same frame lets that refresh put this
        // screen back on top, so wait for it to finish first.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        AppToast.success(context, message);
      } else {
        if (!mounted) return;
        AppToast.success(context, 'Profile saved.');
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Profile saved, but: ${e.message}');
    } on DioException catch (e) {
      if (!mounted) return;
      AppToast.error(context, _messageFor(e));
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final text = data['message']
          .toString()
          .replaceFirst('Cause by:', '')
          .trim();
      if (text.isNotEmpty) return text;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return "Can't reach the server. Check your connection.";
    }
    return 'Could not save your profile. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploading;
    final name = ref.watch(authProvider).displayName;

    return AuthScaffold(
      titleInHeader: true,
      title: widget.apply ? 'Build your creator profile' : 'Edit your profile',
      subtitle: widget.apply
          ? 'This is what brands see before they work with you.'
          : 'Update how brands see you.',
      onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile photo.
            Center(
              child: Column(
                children: [
                  Avatar(url: _avatar, name: name, size: 104),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: busy ? null : _pickAvatar,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(_avatar == null ? 'Add photo' : 'Change photo'),
                  ),
                  if (_avatar != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => _avatar = null),
                      child: const Text(
                        'Remove photo',
                        style: TextStyle(color: AppColors.neutral500),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _headline,
              label: 'Headline',
              hint: 'e.g. Tech reviewer and storyteller',
              icon: Icons.badge_outlined,
              maxLength: _maxHeadline,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: _validateHeadline,
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _bio,
              label: 'Biography',
              hint: 'Who you are, what you create and who follows you',
              icon: Icons.person_outline,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              minLines: 5,
              maxLines: 10,
              maxLength: _maxBio,
              validator: _validateBio,
            ),
            const SizedBox(height: 16),
            _GalleryEditor(
              images: _gallery,
              busy: busy,
              uploading: _uploading,
              onAdd: _addGalleryImage,
              onRemove: (i) => setState(() => _gallery.removeAt(i)),
            ),
            const SizedBox(height: 28),
            AuthButton(
              label: widget.apply ? 'Save and apply' : 'Save profile',
              loading: _saving,
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryEditor extends StatelessWidget {
  const _GalleryEditor({
    required this.images,
    required this.busy,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> images;
  final bool busy;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final canAdd = images.length < _maxGallery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Photos (${images.length}/$_maxGallery)',
            style: const TextStyle(
              color: AppColors.neutral700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < images.length; i++)
              _Thumb(url: images[i], onRemove: busy ? null : () => onRemove(i)),
            if (canAdd)
              Semantics(
                button: true,
                label: 'Add a photo',
                child: InkWell(
                  onTap: busy ? null : onAdd,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.neutral500,
                            size: 28,
                          ),
                  ),
                ),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2, top: 8),
          child: Text(
            'JPG or PNG, up to 5 MB each.',
            style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.onRemove});
  final String url;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppImage(url),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              button: true,
              label: 'Remove photo',
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xCC111111),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
