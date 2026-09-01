import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/feed.dart';
import '../services/feed_service.dart';
import '../services/photo_service.dart';
import '../widgets/common.dart';

class PostComposerScreen extends StatefulWidget {
  const PostComposerScreen({
    super.key,
    this.initialContent,
    this.postType = FeedPost.kTextType,
    this.workout,
  });

  /// Texto já montado — usado quando o post vem do resumo de um treino.
  final String? initialContent;
  final String postType;

  /// Números da sessão, anexados ao post para o feed montar o card.
  final WorkoutPostSummary? workout;

  @override
  State<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends State<PostComposerScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialContent ?? '');

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _publishing = false;

  static const int _maxLength = 255;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await PhotoService.pick(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImage = file;
        _previewBytes = bytes;
      });
    } catch (_) {
      if (mounted) {
        showToast(context, 'Não consegui abrir suas fotos', isError: true);
      }
    }
  }

  Future<void> _publish() async {
    final content = _controller.text.trim();
    if (content.isEmpty && _pickedImage == null) {
      showToast(context, 'Escreva algo ou escolha uma foto', isError: true);
      return;
    }

    setState(() => _publishing = true);
    try {
      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await PhotoService.upload(_pickedImage!);
      }

      await FeedService.create(
        content: content,
        image: imageUrl,
        postType: widget.postType,
        workout: widget.workout,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            if (_pickedImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: WorkutColors.danger),
                title: const Text('Remover foto'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _pickedImage = null;
                    _previewBytes = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.user;
    final isWorkout = widget.postType == FeedPost.kWorkoutType;

    return Scaffold(
      appBar: AppBar(
        title: Text(isWorkout ? 'Postar treino' : 'Nova publicação'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: FilledButton(
              onPressed: _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                minimumSize: const Size(96, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: _publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Publicar'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              WorkutAvatar(
                url: me?.avatarUrl,
                name: me?.fullName ?? 'Eu',
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.fullName ?? 'Atleta Workut',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isWorkout ? 'Resumo do treino' : 'Publicando no feed',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WorkutColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.workout != null) ...[
            const SizedBox(height: 16),
            _WorkoutPreview(workout: widget.workout!),
          ],
          const SizedBox(height: 16),
          WorkutCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 12,
              maxLength: _maxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText:
                    'Conte como foi o treino: carga, PR, como você se sentiu...',
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(fontSize: 15.5, height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          if (_previewBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Image.memory(
                    _previewBytes!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        onPressed: () => setState(() {
                          _pickedImage = null;
                          _previewBytes = null;
                        }),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            onPressed: _publishing ? null : _showImageOptions,
            icon: const Icon(Icons.add_a_photo_outlined, size: 19),
            label: Text(
              _pickedImage == null ? 'Adicionar foto' : 'Trocar foto',
            ),
          ),
        ],
      ),
    );
  }
}


/// Prévia do treino que vai junto do post.
class _WorkoutPreview extends StatelessWidget {
  const _WorkoutPreview({required this.workout});

  final WorkoutPostSummary workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4F4), Color(0xFFF4F6F9)],
        ),
        border: Border.all(color: WorkutColors.brandSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: WorkutColors.brand,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name ?? 'Treino',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${Format.volume(workout.volume)} · ${workout.sets} séries'
                  '${workout.prCount > 0 ? ' · ${workout.prCount} PR' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WorkutColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
