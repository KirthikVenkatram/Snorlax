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
                    const Text('Log meals and track calories/macros against your goals.'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Open nutrition',
                      onPressed: () => GoRouter.of(context).push('/nutrition'),
                    ),
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
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Body composition', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Log check-ins and view body-fat and lean-mass estimates.'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Open body composition',
                      onPressed: () => GoRouter.of(context).push('/body'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goals', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Set and track physique, performance, and primary goals.'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Open goals',
                      onPressed: () => GoRouter.of(context).push('/goals'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Habits', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Track daily and weekly habits, with room for planned exclusions.'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Open habits',
                      onPressed: () => GoRouter.of(context).push('/habits'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adherence', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('See a supportive daily and weekly view of how your plan is going.'),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Open adherence',
                      onPressed: () => GoRouter.of(context).push('/adherence'),
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
