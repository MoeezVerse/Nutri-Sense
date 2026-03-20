import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../widgets/pressable_scale.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.existingProfile,
    required this.accountEmail,
    required this.onComplete,
  });

  final UserProfile? existingProfile;
  /// Email of the signed-in account — profile is stored per user.
  final String accountEmail;
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _cityController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _medicalController;
  String _goal = 'maintain';
  String _activityLevel = 'moderate';
  final List<String> _restrictions = [];

  static final _goals = <List<dynamic>>[
    ['lose_weight', 'Lose weight', FontAwesomeIcons.weightScale],
    ['maintain', 'Maintain weight', FontAwesomeIcons.scaleBalanced],
    ['gain_muscle', 'Gain muscle', FontAwesomeIcons.dumbbell],
  ];

  static const _activityLevels = <List<String>>[
    ['sedentary', 'Sedentary'],
    ['light', 'Light'],
    ['moderate', 'Moderate'],
    ['active', 'Active'],
    ['very_active', 'Very active'],
  ];

  static const _restrictionOptions = [
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Dairy-free',
    'Nut-free',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _cityController = TextEditingController(text: p?.city ?? '');
    _ageController = TextEditingController(
        text: (p != null && p.age > 0) ? '${p.age}' : '');
    _weightController = TextEditingController(
        text: (p != null && p.weightKg > 0) ? '${p.weightKg}' : '');
    _heightController = TextEditingController(
        text: (p != null && p.heightCm > 0) ? '${p.heightCm}' : '');
    _medicalController = TextEditingController(text: p?.medicalNotes ?? '');
    if (p != null) {
      _goal = p.goal;
      _activityLevel = p.activityLevel;
      _restrictions.addAll(p.dietaryRestrictions);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _medicalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = UserProfile(
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
      goal: _goal,
      activityLevel: _activityLevel,
      dietaryRestrictions: List.from(_restrictions),
      medicalNotes: _medicalController.text.trim().isEmpty
          ? null
          : _medicalController.text.trim(),
    );
    final email = widget.accountEmail.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session error: missing account email.')),
        );
      }
      return;
    }
    await ProfileStorage.save(profile, accountEmail: email);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingProfile != null;
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(isEdit),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 8, compact ? 16 : 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full name',
                        icon: FontAwesomeIcons.user,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        icon: FontAwesomeIcons.locationDot,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final singleColumn = constraints.maxWidth < 420;
                          if (singleColumn) {
                            return Column(
                              children: [
                                _buildTextField(
                                  controller: _ageController,
                                  label: 'Age',
                                  icon: FontAwesomeIcons.cakeCandles,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final n = int.tryParse(v ?? '');
                                    if (n == null || n < 10 || n > 120) {
                                      return 'Valid age (10–120)';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _weightController,
                                  label: 'Weight (kg)',
                                  icon: FontAwesomeIcons.weightScale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    final n = double.tryParse(v ?? '');
                                    if (n == null || n < 20 || n > 300) {
                                      return '20–300 kg';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _ageController,
                                  label: 'Age',
                                  icon: FontAwesomeIcons.cakeCandles,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final n = int.tryParse(v ?? '');
                                    if (n == null || n < 10 || n > 120) {
                                      return 'Valid age (10–120)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _weightController,
                                  label: 'Weight (kg)',
                                  icon: FontAwesomeIcons.weightScale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    final n = double.tryParse(v ?? '');
                                    if (n == null || n < 20 || n > 300) {
                                      return '20–300 kg';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _heightController,
                        label: 'Height (cm)',
                        icon: FontAwesomeIcons.rulerVertical,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n < 100 || n > 250) {
                            return '100–250 cm';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Goal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._goals.map((e) => _goalTile(
                            title: e[1] as String,
                            icon: e[2] as IconData,
                            selected: _goal == e[0],
                            onTap: () => setState(() => _goal = e[0] as String),
                          )),
                      const SizedBox(height: 24),
                      const Text(
                        'Activity level',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _activityLevels
                            .map((e) => ChoiceChip(
                                  label: Text(e[1]),
                                  selected: _activityLevel == e[0],
                                  onSelected: (_) =>
                                      setState(() => _activityLevel = e[0]),
                                  selectedColor:
                                      const Color(0xFF2ECC71).withValues(alpha: 0.3),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Dietary restrictions (optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _restrictionOptions.map((opt) {
                          final selected = _restrictions.contains(opt);
                          return FilterChip(
                            label: Text(opt),
                            selected: selected,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _restrictions.add(opt);
                                } else {
                                  _restrictions.remove(opt);
                                }
                              });
                            },
                            selectedColor:
                                const Color(0xFF2ECC71).withValues(alpha: 0.3),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _medicalController,
                        label: 'Medical notes (optional)',
                        icon: FontAwesomeIcons.notesMedical,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 32),
                      PressableScale(
                        child: FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isEdit ? 'Save changes' : 'Get my diet plan',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEdit) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 20, compact ? 16 : 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.leaf,
                color: Color(0xFF2ECC71),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Nutri-Sense',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEdit ? 'Update your profile' : 'Enter your details for a personalized diet plan',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF2ECC71)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _goalTile({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2ECC71).withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2ECC71)
                  : const Color(0xFFE8ECF0),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2ECC71)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF1A1D29)),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: const Color(0xFF2ECC71),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
