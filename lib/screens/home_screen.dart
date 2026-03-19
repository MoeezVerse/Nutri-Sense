import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/food_analysis_service.dart';
import '../widgets/pressable_scale.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _mockNutrition;
  String? _analysisError;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 92,
      );
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
          _isAnalyzing = true;
          _mockNutrition = null;
          _analysisError = null;
        });
        await _analyzeWithAI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _analyzeWithAI() async {
    if (_pickedImage == null) return;
    final file = _pickedImage!;
    try {
      final result = await FoodAnalysisService.analyzeFoodFromFile(file);
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _mockNutrition = result;
        _analysisError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is FoodAnalysisException ? e.message : e.toString();
      setState(() {
        _isAnalyzing = false;
        _analysisError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _pickedImage = null;
      _mockNutrition = null;
      _analysisError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            SliverToBoxAdapter(
              child: _buildScanSection(),
            ),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetTween = Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: animation.drive(offsetTween),
                      child: child,
                    ),
                  );
                },
                child: (_pickedImage != null || _isAnalyzing)
                    ? _buildResultSection()
                    : const SizedBox.shrink(),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: bottomPadding + 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your nutrition & diet companion — scan food, get your plan, reach out for help',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScanSection() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add a photo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn = constraints.maxWidth < 420;
              if (singleColumn) {
                return Column(
                  children: [
                    _ActionCard(
                      icon: FontAwesomeIcons.camera,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: FontAwesomeIcons.image,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: FontAwesomeIcons.camera,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      icon: FontAwesomeIcons.image,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Padding(
      key: const ValueKey<String>('scan_result_section'),
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 0, compact ? 16 : 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Result',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D29),
                ),
              ),
              TextButton.icon(
                onPressed: _clearImage,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('New scan'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_pickedImage != null) _buildImagePreview(),
                  if (_analysisError != null) _buildErrorCard(),
                  if (_mockNutrition != null) _buildNutritionCards(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full image preview: responsive height, BoxFit.contain so entire image is visible and sharp.
  Widget _buildImagePreview() {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = (screenHeight * 0.32).clamp(200.0, 320.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          width: width,
          height: maxHeight,
          color: const Color(0xFFF0F2F5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Image.file(
                  _pickedImage!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  width: width,
                  height: maxHeight,
                ),
              ),
              AnimatedOpacity(
                opacity: _isAnalyzing ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_isAnalyzing,
                  child: Container(
                    color: Colors.black38,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                color: Color(0xFF2ECC71),
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Analyzing...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.orange.shade700),
          const SizedBox(height: 12),
          Text(
            _analysisError!,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _analyzeWithAI,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry analysis'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2ECC71)),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCards() {
    final n = _mockNutrition!;
    final calories = n['calories'] as int? ?? 0;
    final howToMake = n['howToMake'] as String?;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dish name',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2ECC71),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            n['label'] as String,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated per serving',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  FontAwesomeIcons.fire,
                  size: 28,
                  color: Color(0xFF2ECC71),
                ),
                const SizedBox(width: 12),
                Text(
                  '$calories kcal',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D29),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nutrition breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 460;
              final chipWidth = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              final chips = [
                _NutrientChip(
                  label: 'Protein',
                  value: '${n['protein']}g',
                  icon: FontAwesomeIcons.dumbbell,
                ),
                _NutrientChip(
                  label: 'Carbs',
                  value: '${n['carbs']}g',
                  icon: FontAwesomeIcons.breadSlice,
                ),
                _NutrientChip(
                  label: 'Fat',
                  value: '${n['fat']}g',
                  icon: FontAwesomeIcons.droplet,
                ),
                _NutrientChip(
                  label: 'Fiber',
                  value: '${n['fiber']}g',
                  icon: FontAwesomeIcons.wheatAwn,
                ),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: chips
                    .map((c) => SizedBox(width: chipWidth, child: c))
                    .toList(),
              );
            },
          ),
          if (howToMake != null && howToMake.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'How to make it',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECF0)),
              ),
              child: Text(
                howToMake,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Powered by AI (Gemini). Estimates per serving.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8ECF0)),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: const Color(0xFF2ECC71),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D29),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _NutrientChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2ECC71)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D29),
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
