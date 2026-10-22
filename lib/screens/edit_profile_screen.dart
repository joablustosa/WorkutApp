import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/responsive.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import '../services/user_service.dart';
import '../widgets/common.dart';
import 'register_screen.dart' show kSports;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: Session.instance.user?.fullName ?? '');
  late final _aboutController =
      TextEditingController(text: Session.instance.user?.aboutMe ?? '');
  late final _weightController = TextEditingController(
    text: _formatNumber(Session.instance.user?.weight),
  );
  late final _heightController = TextEditingController(
    text: _formatNumber(Session.instance.user?.height),
  );

  late String _sport = Session.instance.user?.sports ?? kSports.first;
  bool _saving = false;
  bool _uploading = false;
  bool _changed = false;

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String _formatNumber(double? value) =>
      value == null || value == 0 ? '' : value.toString().replaceAll('.', ',');

  double? _parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _changePhoto(ImageSource source) async {
    final user = Session.instance.user;
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      final file = await PhotoService.pick(source: source);
      if (file == null) return;

      final url = await PhotoService.uploadProfile(file);
      await UserService.updatePhoto(user, url);

      if (!mounted) return;
      _changed = true;
      showToast(context, 'Foto atualizada!');
      setState(() {});
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        showToast(context, 'Não consegui abrir suas fotos', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showPhotoOptions() {
    // No desktop web não existe câmera para abrir: vai direto ao seletor
    // de arquivos do navegador, sem a folha de opções.
    if (context.isDesktopWeb) {
      _changePhoto(ImageSource.gallery);
      return;
    }

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
                _changePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.of(context).pop();
                _changePhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final user = Session.instance.user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await UserService.update(
        user.copyWith(
          fullName: _nameController.text.trim(),
          aboutMe: _aboutController.text.trim(),
          sports: _sport,
          weight: _parseNumber(_weightController.text),
          height: _parseNumber(_heightController.text),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trocar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha atual'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.changePassword(
        currentPassword: currentController.text,
        newPassword: newController.text,
      );
      if (mounted) showToast(context, 'Senha atualizada!');
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Center(
                child: Stack(
                  children: [
                    WorkutAvatar(
                      url: user?.photo,
                      name: user?.fullName ?? 'Eu',
                      size: 104,
                      borderColor: WorkutColors.brandSoft,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: WorkutColors.brand,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploading ? null : _showPhotoOptions,
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Digite seu nome'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _aboutController,
                maxLines: 3,
                maxLength: 255,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sobre você',
                  hintText: 'Seu objetivo, seu esporte, sua rotina...',
                  alignLabelWithHint: true,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Peso (kg)',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Altura (m)',
                        prefixIcon: Icon(Icons.height_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Modalidade',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sport in kSports)
                    ChoiceChip(
                      label: Text(sport),
                      selected: _sport == sport,
                      showCheckmark: false,
                      selectedColor: WorkutColors.brand,
                      onSelected: (_) => setState(() => _sport = sport),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _sport == sport
                            ? Colors.white
                            : WorkutColors.brandDark,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar alterações'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.lock_reset_rounded, size: 19),
                label: const Text('Trocar senha'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
