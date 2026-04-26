import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../widgets/plan_card.dart';
import '../../widgets/create_plan_sheet.dart';

const _categories = [
  {'id': 'all', 'label': 'All', 'emoji': ''},
  {'id': 'food', 'label': 'Food', 'emoji': '🍜'},
  {'id': 'play', 'label': 'Play', 'emoji': '🏏'},
  {'id': 'gym', 'label': 'Gym', 'emoji': '💪'},
  {'id': 'ride', 'label': 'Ride', 'emoji': '🏍️'},
  {'id': 'hangout', 'label': 'Hangout', 'emoji': '☕'},
  {'id': 'trek', 'label': 'Trek', 'emoji': '🥾'},
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedCat = 'all';
  List<dynamic> _plans = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String _userName = 'There';
  String _currentCity = 'Earth';
  int _unseenNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadUser();
    _loadNotifications();
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
      if (mounted) {
        setState(() {
          _plans = plans;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await ApiClient.getNotifications();
      final unseenCount = await ApiClient.getUnseenNotificationCount();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _unseenNotificationCount = unseenCount;
        });
      }
    } catch (_) {}
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

  Future<void> _openNotificationsSheet() async {
    try {
      await ApiClient.markAllNotificationsRead();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _unseenNotificationCount = 0;
        _notifications =
            _notifications.map((n) => {...n, 'is_read': true}).toList();
      });
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, localSetState) => Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(
                              color: AppColors.sub,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final n = _notifications[i];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 6, 10),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin:
                                      const EdgeInsets.only(top: 7, right: 10),
                                  decoration: BoxDecoration(
                                    color: n['is_read'] == true
                                        ? AppColors.border
                                        : AppColors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['title']?.toString() ??
                                            'Notification',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n['body']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.sub,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert,
                                      size: 18, color: AppColors.sub),
                                  onSelected: (value) async {
                                    if (value != 'delete') return;
                                    final id = n['id']?.toString();
                                    if (id == null) return;
                                    try {
                                      await ApiClient.deleteNotification(id);
                                    } catch (_) {
                                      return;
                                    }
                                    if (!mounted) return;
                                    setState(() {
                                      _notifications.removeAt(i);
                                    });
                                    localSetState(() {});
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadPlans();
            await _loadNotifications();
          },
          color: AppColors.orange,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildCategoryFilter()),
            _loading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
                : _plans.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildNoPlansEmptyState(),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: PlanCard(
                                  key: ValueKey(_plans[i]['id']?.toString() ?? i.toString()),
                                  plan: _plans[i],
                                  onJoin: (id) async {
                                    try {
                                      await ApiClient.joinPlan(id);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Joined plan successfully 🎉')));
                                      }
                                      _loadPlans();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Could not join plan')));
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

  Widget _buildNoPlansEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off_rounded,
                size: 54,
                color: AppColors.sub,
              ),
              const SizedBox(height: 12),
              const Text(
                'No plans nearby yet',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Be the first one to create something happening in your city.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.sub,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showCreateSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create First Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      color: AppColors.card,
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hey $_userName 👋',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontSize: 24)),
          Text('📍 $_currentCity · ${_plans.length} plans nearby',
              style: const TextStyle(fontSize: 12, color: AppColors.sub)),
        ])),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: _openNotificationsSheet,
              icon: const Icon(Icons.notifications_none_rounded,
                  color: AppColors.ink),
            ),
            if (_unseenNotificationCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    _unseenNotificationCount > 99
                        ? '99+'
                        : '$_unseenNotificationCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
