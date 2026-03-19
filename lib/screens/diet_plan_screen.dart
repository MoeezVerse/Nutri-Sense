import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/workout_plan_ai_service.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/skeleton_shimmer.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  UserProfile? _profile;
  bool _loading = true;
  List<_WeightEntry> _weightEntries = [];
  final TextEditingController _weightLogController = TextEditingController();
  bool _savingWeight = false;
  bool _generatingAiPlan = false;
  List<_ExerciseData> _aiExercises = [];
  DateTime? _aiPlanGeneratedAt;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final p = await ProfileStorage.load();
    final logs = await _loadWeightEntries();
    final ai = await _loadAiExercises();
    final aiGeneratedAt = await _loadAiGeneratedAt();
    setState(() {
      _profile = p;
      _weightEntries = logs;
      _aiExercises = ai;
      _aiPlanGeneratedAt = aiGeneratedAt;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _weightLogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            child: SkeletonShimmer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 18, width: 170, radius: 999),
                  SizedBox(height: 14),
                  SkeletonBox(height: 76, radius: 16),
                  SizedBox(height: 10),
                  SkeletonBox(height: 76, radius: 16),
                  SizedBox(height: 10),
                  SkeletonBox(height: 76, radius: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.clipboardList,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter your details first',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Go to Profile and fill in your info to get a personalized diet plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final plan = _generatePlan(_profile!);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF2ECC71),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(_profile!.name)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryCard(_profile!, plan),
                      const SizedBox(height: 24),
                      const Text(
                        'Daily targets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTargetGrid(plan),
                      const SizedBox(height: 24),
                      const Text(
                        'Personalized daily nutrition plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMealCards(plan),
                      const SizedBox(height: 24),
                      const Text(
                        'Cardio and exercise',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildExerciseSection(_profile!),
                      const SizedBox(height: 24),
                      const Text(
                        'Daily weight tracker',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildWeightTrackerCard(_profile!),
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

  Widget _buildHeader(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Diet plan for $name',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _generatePlan(UserProfile p) {
    // Mifflin-St Jeor (neutral formula)
    double baseCal = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age - 80;
    double mult = 1.2;
    switch (p.activityLevel) {
      case 'light':
        mult = 1.375;
        break;
      case 'moderate':
        mult = 1.55;
        break;
      case 'active':
        mult = 1.725;
        break;
      case 'very_active':
        mult = 1.9;
        break;
    }
    double calories = baseCal * mult;
    if (p.goal == 'lose_weight') calories -= 400;
    if (p.goal == 'gain_muscle') calories += 300;
    calories = calories.clamp(1200.0, 3500.0);

    final protein = (p.weightKg * 1.6).round();
    final carbs = ((calories * 0.45) / 4).round();
    final fat = ((calories * 0.3) / 9).round();
    const fiber = 25;

    return {
      'calories': calories.round(),
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'goal': p.goal,
    };
  }

  Widget _buildSummaryCard(UserProfile p, Map<String, dynamic> plan) {
    final goalLabel = {
      'lose_weight': 'Lose weight',
      'maintain': 'Maintain weight',
      'gain_muscle': 'Gain muscle',
    }[plan['goal']] ?? 'Maintain';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                FontAwesomeIcons.bullseye,
                color: Color(0xFF2ECC71),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                goalLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D29),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'BMI: ${p.bmi.toStringAsFixed(1)} • Based on your activity level and goals',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetGrid(Map<String, dynamic> plan) {
    final items = <List<dynamic>>[
      ['Calories', '${plan['calories']}', 'kcal', FontAwesomeIcons.fire],
      ['Protein', '${plan['protein']}', 'g', FontAwesomeIcons.dumbbell],
      ['Carbs', '${plan['carbs']}', 'g', FontAwesomeIcons.breadSlice],
      ['Fat', '${plan['fat']}', 'g', FontAwesomeIcons.droplet],
      ['Fiber', '${plan['fiber']}', 'g', FontAwesomeIcons.wheatAwn],
    ];
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 3 : 2;
    final ratio = width >= 900 ? 1.6 : 1.4;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: ratio,
      children: items
          .map((e) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(e[3] as IconData, size: 22, color: const Color(0xFF2ECC71)),
                    const SizedBox(height: 8),
                    Text(
                      e[0] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${e[1]} ${e[2]}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D29),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMealCards(Map<String, dynamic> plan) {
    final p = _profile!;
    final hasVegan = p.dietaryRestrictions.contains('Vegan');
    final hasVegetarian = p.dietaryRestrictions.contains('Vegetarian');
    final proteinHint = hasVegan
        ? 'tofu, lentils, beans'
        : hasVegetarian
            ? 'paneer, eggs, lentils'
            : 'chicken, fish, eggs';
    final goalLine = p.goal == 'lose_weight'
        ? 'Keep portions moderate and prioritize fiber.'
        : p.goal == 'gain_muscle'
            ? 'Include one extra protein serving and a post-workout snack.'
            : 'Balance portions to maintain steady energy.';
    final meals = <List<dynamic>>[
      ['Breakfast', '07:00–09:00', 'Oats + fruit + $proteinHint', FontAwesomeIcons.sun],
      ['Lunch', '12:00–14:00', 'Whole grains + vegetables + $proteinHint', FontAwesomeIcons.bowlFood],
      ['Snack', '15:00–16:00', 'Fruit + yogurt or nuts', FontAwesomeIcons.appleWhole],
      ['Dinner', '18:00–20:00', 'Light carbs + vegetables + lean protein', FontAwesomeIcons.moon],
    ];
    return Column(
      children: [
        ...meals.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8ECF0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(m[3] as IconData, color: const Color(0xFF2ECC71), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m[0] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      Text(
                        m[1] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m[2] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8ECF0)),
          ),
          child: Text(
            goalLine,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseSection(UserProfile p) {
    final aiActive = _aiExercises.isNotEmpty;
    final exercises = aiActive ? _aiExercises : _buildExerciseCards(p);
    final weeklyGoal = _buildWeeklyWorkoutGoal(p);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            weeklyGoal,
            style: TextStyle(
              fontSize: 13,
              color: Colors.green.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Container(
                key: ValueKey<String>(aiActive ? 'ai_badge' : 'default_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: aiActive
                    ? const Color(0xFF1A1D29).withValues(alpha: 0.12)
                    : const Color(0xFF95A5A6).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: aiActive
                      ? const Color(0xFF1A1D29).withValues(alpha: 0.35)
                      : const Color(0xFF7F8C8D).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    aiActive ? Icons.auto_awesome : Icons.rule,
                    size: 14,
                    color: aiActive
                        ? const Color(0xFF1A1D29)
                        : const Color(0xFF5D6D7E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    aiActive ? 'AI Plan Active' : 'Default Plan Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: aiActive
                          ? const Color(0xFF1A1D29)
                          : const Color(0xFF5D6D7E),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          aiActive
              ? 'AI personalized content may vary with each regeneration.'
              : 'Using stable default workout logic based on your profile.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PressableScale(
                child: FilledButton.icon(
                  onPressed: _generatingAiPlan ? null : () => _generateAiPlan(p),
                  icon: _generatingAiPlan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    _generatingAiPlan
                        ? 'Generating AI plan...'
                        : 'AI regenerate weekly workout',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1D29),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            if (_aiExercises.isNotEmpty) ...[
              const SizedBox(width: 8),
              PressableScale(
                child: OutlinedButton(
                  onPressed: _clearAiPlan,
                  child: const Text('Reset'),
                ),
              ),
            ],
          ],
        ),
        if (_aiPlanGeneratedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Last AI update: ${_formatDateTime(_aiPlanGeneratedAt!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (isWide)
          GridView.builder(
            itemCount: exercises.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, i) => _ExerciseCard(
              data: exercises[i],
              aiStyled: aiActive,
            ),
          )
        else
          ...exercises.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExerciseCard(
                data: e,
                aiStyled: aiActive,
              ),
            ),
          ),
      ],
    );
  }

  String _buildWeeklyWorkoutGoal(UserProfile p) {
    final trend = _weightTrendKg();
    final trendText = trend == null
        ? 'No trend yet'
        : (trend > 0
            ? '+${trend.toStringAsFixed(1)} kg this week'
            : '${trend.toStringAsFixed(1)} kg this week');
    if (p.goal == 'lose_weight') {
      return 'Weekly target: 180-240 cardio minutes, 2 strength days, and about 0.3-0.7 kg fat loss/week ($trendText).';
    }
    if (p.goal == 'gain_muscle') {
      return 'Weekly target: 4 strength sessions, 1-2 recovery cardio sessions, and about 0.2-0.4 kg lean gain/week ($trendText).';
    }
    return 'Weekly target: 150+ active minutes, 2 strength sessions, and steady body-weight maintenance ($trendText).';
  }

  double? _weightTrendKg() {
    if (_weightEntries.length < 2) return null;
    final recent = _weightEntries.first.weightKg;
    final older = _weightEntries.length >= 7
        ? _weightEntries[6].weightKg
        : _weightEntries.last.weightKg;
    return recent - older;
  }

  List<_ExerciseData> _buildExerciseCards(UserProfile p) {
    final bmi = p.bmi;
    final isHighBmi = bmi >= 28;
    final isLowBmi = bmi < 19;
    final highActivity = p.activityLevel == 'active' || p.activityLevel == 'very_active';
    final moderateActivity = p.activityLevel == 'moderate';

    if (p.goal == 'lose_weight') {
      return [
        _ExerciseData(
          title: 'Brisk Walk',
          duration: isHighBmi ? '40-50 min, 5x/week' : '30-40 min, 5x/week',
          description: 'Steady pace cardio to increase calorie burn while keeping joint stress manageable.',
          setsPlan: isHighBmi
              ? '1 continuous session'
              : '2 x 20-minute blocks (morning/evening)',
          intensity: isHighBmi ? 'Low to moderate (RPE 5/10)' : 'Moderate (RPE 6/10)',
          restPlan: '1 full rest day/week',
          imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=1200',
        ),
        _ExerciseData(
          title: 'HIIT Circuit',
          duration: highActivity ? '20-25 min, 3x/week' : '15-20 min, 2x/week',
          description: 'Intervals improve conditioning and support fat loss.',
          setsPlan: highActivity
              ? '8 rounds: 40s work / 20s rest'
              : '6 rounds: 30s work / 30s rest',
          intensity: 'Moderate to high (RPE 7-8/10)',
          restPlan: '48h gap between HIIT sessions',
          imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=1200',
        ),
        const _ExerciseData(
          title: 'Strength Foundation',
          duration: '30-40 min, 2x/week',
          description: 'Basic strength training protects muscle while reducing body fat.',
          setsPlan: '3 sets x 10-12 reps (squat, push, row, hinge, core)',
          intensity: 'Moderate (RPE 6-7/10)',
          restPlan: '60-90 sec between sets',
          imageUrl: 'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=1200',
        ),
      ];
    }
    if (p.goal == 'gain_muscle') {
      return [
        _ExerciseData(
          title: 'Strength Training',
          duration: highActivity ? '60 min, 4-5x/week' : '45-55 min, 4x/week',
          description: 'Focus on compound lifts with progressive overload.',
          setsPlan: isLowBmi
              ? '4 sets x 8-12 reps (add load weekly)'
              : '4 sets x 6-10 reps + 1 accessory finisher',
          intensity: 'Moderate to high (RPE 7-9/10)',
          restPlan: '90-150 sec between compound sets',
          imageUrl: 'https://images.unsplash.com/photo-1599058917212-d750089bc07e?w=1200',
        ),
        const _ExerciseData(
          title: 'Recovery Cardio',
          duration: '15-20 min, 1-2x/week',
          description: 'Light cardio supports recovery and cardiovascular fitness.',
          setsPlan: '1 continuous low-intensity session',
          intensity: 'Low (RPE 4-5/10)',
          restPlan: 'Do after lifting or on rest day',
          imageUrl: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=1200',
        ),
        const _ExerciseData(
          title: 'Upper/Lower Split',
          duration: '2 focused sessions/week',
          description: 'Dedicated split improves training volume for muscle growth.',
          setsPlan: '4 exercises each day, 3-4 sets x 8-12 reps',
          intensity: 'Moderate to high (RPE 7-8/10)',
          restPlan: 'At least 48h before repeating same muscle group',
          imageUrl: 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=1200',
        ),
      ];
    }
    return [
      _ExerciseData(
        title: 'Moderate Cardio',
        duration: moderateActivity ? '30 min, 4x/week' : '25-35 min, 3-4x/week',
        description: 'Jogging or cycling helps maintain fitness and stamina.',
        setsPlan: '1 continuous session',
        intensity: 'Moderate (RPE 6/10)',
        restPlan: '1-2 lighter days/week',
        imageUrl: 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=1200',
      ),
      const _ExerciseData(
        title: 'Mobility & Core',
        duration: '20 min, 3x/week',
        description: 'Mobility and core work improves posture and movement quality.',
        setsPlan: '3 rounds: 5 mobility drills + 3 core moves',
        intensity: 'Low to moderate (RPE 5/10)',
        restPlan: '30-45 sec between rounds',
        imageUrl: 'https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=1200',
      ),
      const _ExerciseData(
        title: 'Full-body Strength',
        duration: '35-45 min, 2x/week',
        description: 'Maintains lean muscle and supports long-term metabolism.',
        setsPlan: '3 sets x 8-12 reps across 5 major movements',
        intensity: 'Moderate (RPE 6-7/10)',
        restPlan: '60-90 sec between sets',
        imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1200',
      ),
    ];
  }

  Widget _buildWeightTrackerCard(UserProfile p) {
    final latest = _weightEntries.isNotEmpty ? _weightEntries.first.weightKg : p.weightKg;
    final diff = latest - p.weightKg;
    final diffLabel = diff == 0
        ? 'No change'
        : '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg vs starting weight';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: ${latest.toStringAsFixed(1)} kg',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D29),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diffLabel,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightLogController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter today\'s weight (kg)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PressableScale(
                child: FilledButton(
                  onPressed: _savingWeight ? null : _addWeightEntry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                  child: _savingWeight
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
          if (_weightEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 6),
            ..._weightEntries.take(7).map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.dateLabel,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                    Text(
                      '${e.weightKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1D29),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addWeightEntry() async {
    final n = double.tryParse(_weightLogController.text.trim());
    if (n == null || n < 20 || n > 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight between 20 and 400 kg')),
      );
      return;
    }
    setState(() => _savingWeight = true);
    final now = DateTime.now();
    final entry = _WeightEntry(dateIso: now.toIso8601String(), weightKg: n);
    final updated = [entry, ..._weightEntries];
    await _saveWeightEntries(updated);
    if (!mounted) return;
    setState(() {
      _weightEntries = updated;
      _savingWeight = false;
      _weightLogController.clear();
    });
  }

  Future<List<_WeightEntry>> _loadWeightEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('nutrisense_weight_entries') ?? [];
    return raw.map(_WeightEntry.fromStorage).toList();
  }

  Future<void> _saveWeightEntries(List<_WeightEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'nutrisense_weight_entries',
      entries.map((e) => e.toStorage()).toList(),
    );
  }

  Future<void> _generateAiPlan(UserProfile p) async {
    setState(() => _generatingAiPlan = true);
    try {
      final trend = _weightTrendKg();
      final trendText = trend == null
          ? 'No trend yet'
          : '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)} kg this week';
      final ai = await WorkoutPlanAIService.generateWeeklyWorkout(
        profile: p,
        weeklyTrendText: trendText,
      );
      final mapped = ai
          .map(
            (e) => _ExerciseData(
              title: '${e['day']}: ${e['title']}',
              duration: e['duration'] ?? '',
              description: e['description'] ?? '',
              setsPlan: e['setsPlan'] ?? '',
              intensity: e['intensity'] ?? '',
              restPlan: e['restPlan'] ?? '',
              imageUrl:
                  'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=1200',
            ),
          )
          .toList();
      await _saveAiExercises(mapped);
      if (!mounted) return;
      setState(() {
        _aiExercises = mapped;
        _aiPlanGeneratedAt = DateTime.now();
        _generatingAiPlan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI workout plan updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingAiPlan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _clearAiPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nutrisense_ai_workout_plan');
    if (!mounted) return;
    setState(() {
      _aiExercises = [];
      _aiPlanGeneratedAt = null;
    });
  }

  Future<void> _saveAiExercises(List<_ExerciseData> data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'generatedAt': DateTime.now().toIso8601String(),
      'items': data
          .map(
            (e) => {
              'title': e.title,
              'duration': e.duration,
              'description': e.description,
              'setsPlan': e.setsPlan,
              'intensity': e.intensity,
              'restPlan': e.restPlan,
              'imageUrl': e.imageUrl,
            },
          )
          .toList(),
    };
    await prefs.setString('nutrisense_ai_workout_plan_json', jsonEncode(payload));
    // Cleanup old format key if it exists
    await prefs.remove('nutrisense_ai_workout_plan');
  }

  Future<List<_ExerciseData>> _loadAiExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('nutrisense_ai_workout_plan_json');
    if (rawJson == null || rawJson.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final items = decoded['items'] as List<dynamic>? ?? [];
      return items.map((item) {
        final m = item as Map<String, dynamic>;
        return _ExerciseData(
          title: (m['title'] ?? '').toString(),
          duration: (m['duration'] ?? '').toString(),
          description: (m['description'] ?? '').toString(),
          setsPlan: (m['setsPlan'] ?? '').toString(),
          intensity: (m['intensity'] ?? '').toString(),
          restPlan: (m['restPlan'] ?? '').toString(),
          imageUrl: (m['imageUrl'] ??
                  'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=1200')
              .toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<DateTime?> _loadAiGeneratedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('nutrisense_ai_workout_plan_json');
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final iso = decoded['generatedAt'] as String?;
      if (iso == null || iso.isEmpty) return null;
      return DateTime.tryParse(iso);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd $hh:$min';
  }
}

class _ExerciseData {
  final String title;
  final String duration;
  final String description;
  final String setsPlan;
  final String intensity;
  final String restPlan;
  final String imageUrl;

  const _ExerciseData({
    required this.title,
    required this.duration,
    required this.description,
    required this.setsPlan,
    required this.intensity,
    required this.restPlan,
    required this.imageUrl,
  });
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseData data;
  final bool aiStyled;

  const _ExerciseCard({
    required this.data,
    this.aiStyled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: aiStyled
            ? const Color(0xFF1A1D29).withValues(alpha: 0.03)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: aiStyled
              ? const Color(0xFF1A1D29).withValues(alpha: 0.18)
              : const Color(0xFFE8ECF0),
        ),
        boxShadow: aiStyled
            ? [
                BoxShadow(
                  color: const Color(0xFF1A1D29).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              data.imageUrl,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 140,
                color: const Color(0xFFEFF3F6),
                alignment: Alignment.center,
                child: const Icon(Icons.fitness_center, size: 36, color: Color(0xFF1A1D29)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.duration,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Text(
                  data.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: aiStyled
                        ? const Color(0xFF1A1D29).withValues(alpha: 0.04)
                        : const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: aiStyled
                          ? const Color(0xFF1A1D29).withValues(alpha: 0.18)
                          : const Color(0xFFE8ECF0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (aiStyled) ...[
                        const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: Color(0xFF1A1D29),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'AI personalized',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1D29),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        'Sets/Reps: ${data.setsPlan}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D29),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Intensity: ${data.intensity}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Rest: ${data.restPlan}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
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

class _WeightEntry {
  final String dateIso;
  final double weightKg;

  const _WeightEntry({required this.dateIso, required this.weightKg});

  String toStorage() => '$dateIso|$weightKg';

  static _WeightEntry fromStorage(String raw) {
    final parts = raw.split('|');
    if (parts.length != 2) {
      return _WeightEntry(dateIso: DateTime.now().toIso8601String(), weightKg: 0);
    }
    return _WeightEntry(
      dateIso: parts[0],
      weightKg: double.tryParse(parts[1]) ?? 0,
    );
  }

  String get dateLabel {
    final d = DateTime.tryParse(dateIso);
    if (d == null) return 'Unknown date';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
