import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

const List<String> kSports = [
  'Musculação',
  'Crossfit',
  'Corrida',
  'Funcional',
  'Calistenia',
  'Luta',
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _weightController = TextEditingController(text: '75');
  final _heightController = TextEditingController(text: '1,75');

  DateTime? _birthDate;
  String _sport = kSports.first;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: now,
      helpText: 'Sua data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  double? _parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    if (_birthDate == null) {
      showToast(context, 'Escolha sua data de nascimento', isError: true);
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      showToast(context, 'As senhas não são iguais', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.register(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        birthDate: _birthDate!,
        weight: _parseNumber(_weightController.text) ?? 0,
        height: _parseNumber(_heightController.text) ?? 0,
        sport: _sport,
      );

      // Entra direto com as credenciais recém-criadas.
      await AuthService.login(
        username: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                const BrandHeader(
                  title: 'Bem-vindo\nao Workut.',
                  subtitle:
                      'Leva menos de um minuto. Depois é só montar o treino e postar.',
                ),
                Positioned(
                  top: 44,
                  right: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Informe seu e-mail';
                        if (!text.contains('@') || !text.contains('.')) {
                          return 'E-mail inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: WorkutColors.muted,
                          ),
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 4)
                          ? 'Use ao menos 4 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirme a senha',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Repita a senha'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickBirthDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          _birthDate == null
                              ? 'Escolher data'
                              : Format.fullDate(_birthDate),
                          style: TextStyle(
                            fontSize: 15,
                            color: _birthDate == null
                                ? WorkutColors.muted
                                : WorkutColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Peso (kg)',
                              prefixIcon: Icon(Icons.monitor_weight_outlined),
                            ),
                            validator: (value) {
                              final parsed = _parseNumber(value ?? '');
                              return (parsed == null || parsed <= 0)
                                  ? 'Inválido'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Altura (m)',
                              prefixIcon: Icon(Icons.height_rounded),
                            ),
                            validator: (value) {
                              final parsed = _parseNumber(value ?? '');
                              return (parsed == null || parsed <= 0)
                                  ? 'Inválido'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Sua modalidade',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
                            onSelected: (_) => setState(() => _sport = sport),
                            showCheckmark: false,
                            selectedColor: WorkutColors.brand,
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
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Criar conta e entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
