import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/theme/app_colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    const ProgressRing(
                      progress: 0,
                      color: AppColors.accentGreen,
                      center: Text('0 kcal'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Nutrition and habits land here in Phase 3+.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workouts', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Log strength and general sessions, and sync Strava activities.'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Open workouts',
                      onPressed: () => GoRouter.of(context).push('/workouts'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
