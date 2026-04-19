import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../widgets/plan_card.dart';
import '../../widgets/create_plan_sheet.dart';

const _categories = [
  {'id': 'all',     'label': 'All',     'emoji': ''},
  {'id': 'food',    'label': 'Food',    'emoji': '🍜'},
  {'id': 'play',    'label': 'Play',    'emoji': '🏏'},
  {'id': 'gym',     'label': 'Gym',     'emoji': '💪'},
  {'id': 'ride',    'label': 'Ride',    'emoji': '🏍️'},
  {'id': 'hangout', 'label': 'Hangout', 'emoji': '☕'},
  {'id': 'trek',    'label': 'Trek',    'emoji': '🥾'},
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedCat = 'all';
  List<dynamic> _plans = [];
  bool _loading = true;
  String _userName = 'There';
  String _currentCity = 'Earth';

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ApiClient.getMe();
      if (mounted) {
        setState(() {
          _userName = user['name']?.split(' ')[0] ?? 'There';
          _currentCity = user['current_city'] ?? 'Earth';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await ApiClient.getPlans(
        category: _selectedCat == 'all' ? null : _selectedCat,
      );
      setState(() { _plans = plans; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePlanSheet(
        onCreated: (data) async {
          await ApiClient.createPlan(data);
          _loadPlans();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPlans,
          color: AppColors.orange,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildCategoryFilter()),
            _loading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PlanCard(plan: _plans[i], onJoin: (id) async {
                          try {
                            await ApiClient.joinPlan(id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined plan successfully 🎉')));
                            }
                            _loadPlans();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not join plan')));
                            }
                          }
                        }),
                      ),
                      childCount: _plans.length,
                    ),
                  ),
                ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      color: AppColors.card,
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hey $_userName 👋', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 24)),
          Text('📍 $_currentCity · ${_plans.length} plans nearby',
            style: const TextStyle(fontSize: 12, color: AppColors.sub)),
        ])),
        ElevatedButton.icon(
          onPressed: _showCreateSheet,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Plan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      color: AppColors.card,
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = _categories[i];
          final active = _selectedCat == c['id'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCat = c['id']!);
              _loadPlans();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.orange : const Color(0xFFF0EFEA),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${c['emoji']} ${c['label']}'.trim(),
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: active ? Colors.white : AppColors.sub,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
