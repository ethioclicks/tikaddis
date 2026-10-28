import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import 'app_toast.dart';

class PromotionBriefDetails extends ConsumerStatefulWidget {
  const PromotionBriefDetails({super.key, required this.request});
  final PromotionRequest request;
  @override
  ConsumerState<PromotionBriefDetails> createState() =>
      _PromotionBriefDetailsState();
}

class _PromotionBriefDetailsState extends ConsumerState<PromotionBriefDetails> {
  bool _busy = false;
  Future<void> _open(PromotionAttachment file) async {
    setState(() => _busy = true);
    try {
      final response = await ref
          .read(apiServiceProvider)
          .downloadPromotionAttachment(file.id);
      final bytes = Uint8List.fromList(response.data!);
      if (!mounted) return;
      if (file.contentType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(file.fileName),
                  trailing: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.memory(
                      bytes,
                      errorBuilder: (_, error, stack) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('This image could not be displayed.'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        final path = await FilePicker.platform.saveFile(
          fileName: file.fileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (path != null &&
            !kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          await File(path).writeAsBytes(bytes);
        }
        if (mounted && path != null) {
          AppToast.success(
            context,
            'Attachment saved. Open it from your files.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'Could not open the attachment. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.brief.isEmpty && r.attachments.isEmpty && r.proposedBudget == null) {
      return const SizedBox.shrink();
    }
    const labels = {
      'campaignTitle': 'Campaign',
      'brandName': 'Brand / business',
      'objective': 'Objective',
      'targetAudience': 'Target audience',
      'deliverables': 'Requested deliverables',
      'callToAction': 'Call to action',
    };
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        r.brief['campaignTitle'] ?? 'Campaign brief',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: const Text('View full brief and attachments'),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in r.brief.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${labels[entry.key] ?? entry.key}: ${entry.value}'),
          ),
        if ((r.promotionText ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Creative brief: ${r.promotionText}'),
          ),
        if (r.dateList.isNotEmpty)
          Text(
            'Requested posting dates: ${r.dateList.map(Fmt.date).join(', ')}',
          ),
        if (r.proposedBudget != null)
          Text(
            'Proposed budget: ${Fmt.birr(r.proposedBudget!)} (subject to agreement)',
          ),
        for (final file in r.attachments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              file.contentType.startsWith('image/')
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_outlined,
            ),
            title: Text(file.fileName),
            subtitle: Text('${(file.byteSize / 1024).ceil()} KB'),
            trailing: const Icon(Icons.download_outlined),
            onTap: _busy ? null : () => _open(file),
          ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}
