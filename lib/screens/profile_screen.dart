import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import 'onboarding_screen.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/skeleton_shimmer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onProfileUpdated,
    required this.onSignedOut,
  });

  final VoidCallback onProfileUpdated;
  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await ProfileStorage.load();
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          existingProfile: _profile,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
    await _loadProfile();
    widget.onProfileUpdated();
  }

  Future<void> _signOut() async {
    if (!mounted) return;
    widget.onProfileUpdated();
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 260,
            child: SkeletonShimmer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBox(height: 80, width: 80, radius: 999),
                  SizedBox(height: 16),
                  SkeletonBox(height: 18, width: 130, radius: 999),
                  SizedBox(height: 12),
                  SkeletonBox(height: 12, width: 200),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: 170),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.userPlus,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Enter your details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your profile to get a personalized diet plan and better recommendations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => OnboardingScreen(
                                onComplete: () {
                                  Navigator.of(context).pop();
                                  _loadProfile();
                                  widget.onProfileUpdated();
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add my details'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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

    final p = _profile!;
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          color: const Color(0xFF2ECC71),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(compact ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFF2ECC71).withValues(alpha: 0.2),
                        child: Text(
                          p.name.isNotEmpty
                              ? p.name.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2ECC71),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontSize: compact ? 20 : 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D29),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InfoRow(
                      icon: FontAwesomeIcons.locationDot,
                      label: 'City',
                      value: p.city.isEmpty ? 'Not set' : p.city,
                    ),
                    _InfoRow(
                      icon: FontAwesomeIcons.cakeCandles,
                      label: 'Age',
                      value: '${p.age} years',
                    ),
                    _InfoRow(
                      icon: FontAwesomeIcons.weightScale,
                      label: 'Weight',
                      value: '${p.weightKg} kg',
                    ),
                    _InfoRow(
                      icon: FontAwesomeIcons.rulerVertical,
                      label: 'Height',
                      value: '${p.heightCm} cm',
                    ),
                    _InfoRow(
                      icon: FontAwesomeIcons.chartLine,
                      label: 'BMI',
                      value: p.bmi.toStringAsFixed(1),
                    ),
                    _InfoRow(
                      icon: FontAwesomeIcons.bullseye,
                      label: 'Goal',
                      value: _goalLabel(p.goal),
                    ),
                    _InfoRow(
                      icon: FontAwesomeIcons.personRunning,
                      label: 'Activity',
                      value: _activityLabel(p.activityLevel),
                    ),
                    if (p.dietaryRestrictions.isNotEmpty)
                      _InfoRow(
                        icon: FontAwesomeIcons.leaf,
                        label: 'Restrictions',
                        value: p.dietaryRestrictions.join(', '),
                      ),
                    if (p.medicalNotes != null && p.medicalNotes!.isNotEmpty)
                      _InfoRow(
                        icon: FontAwesomeIcons.notesMedical,
                        label: 'Medical notes',
                        value: p.medicalNotes!,
                      ),
                    const SizedBox(height: 32),
                    PressableScale(
                      child: FilledButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit, size: 20),
                        label: const Text('Edit profile'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PressableScale(
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text('Sign out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1D29),
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _goalLabel(String goal) {
    const m = {
      'lose_weight': 'Lose weight',
      'maintain': 'Maintain weight',
      'gain_muscle': 'Gain muscle',
    };
    return m[goal] ?? goal;
  }

  String _activityLabel(String a) {
    const m = {
      'sedentary': 'Sedentary',
      'light': 'Light',
      'moderate': 'Moderate',
      'active': 'Active',
      'very_active': 'Very active',
    };
    return m[a] ?? a;
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your profile',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final labelWidth = width < 360 ? 90.0 : 110.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2ECC71)),
          const SizedBox(width: 14),
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D29),
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
