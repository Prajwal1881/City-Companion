import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import 'package:intl/intl.dart';

class PlanDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> plan;

  const PlanDetailsScreen({super.key, required this.plan});

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  late Map<String, dynamic> _plan;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _refreshPlan();
  }

  Future<void> _refreshPlan() async {
    try {
      final updatedPlan = await ApiClient.getPlan(_plan['id']);
      if (mounted) setState(() => _plan = updatedPlan);
    } catch (_) {}
  }

  Future<void> _handleJoin() async {
    setState(() => _loading = true);
    try {
      await ApiClient.joinPlan(_plan['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined plan successfully 🎉')));
      }
      await _refreshPlan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not join plan')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Plan',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Are you sure you want to cancel this plan? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nevermind')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.rose),
              child: const Text('Yes, Cancel Plan',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ApiClient.deletePlan(_plan['id']);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan cancelled successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not cancel plan')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Plan',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to leave this plan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nevermind')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.rose),
              child: const Text('Yes, Leave',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ApiClient.leavePlan(_plan['id']);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left plan successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not leave plan')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPlanChat() {
    final convId = _plan['conversation_id']?.toString();
    if (convId == null || convId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat thread not available yet')),
      );
      return;
    }
    context.push('/chat/$convId');
  }

  @override
  Widget build(BuildContext context) {
    final isHost = _plan['is_host'] == true;
    final hasJoined = _plan['has_joined'] == true;
    final joined = (_plan['joined_count'] as num?)?.toInt() ?? 0;
    final max = (_plan['max_members'] as num?)?.toInt() ?? 10;
    final pct = max > 0 ? (joined / max).clamp(0.0, 1.0) : 0.0;
    final isFull = pct >= 1.0;

    final date = DateTime.tryParse(_plan['plan_date'] ?? '');
    final dateStr =
        date != null ? DateFormat('EEEE, MMM d • h:mm a').format(date) : '';

    final members = _plan['members'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Plan Details',
            style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Host Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.orange,
                          child: Text(
                            (_plan['host_name'] as String? ?? 'U').isNotEmpty 
                                ? (_plan['host_name'] as String)[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hosted by ${_plan['host_name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('Organizer',
                                style: TextStyle(
                                    color: AppColors.sub, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(_plan['title'] ?? '',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 16),

                    // Meta Row
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: AppColors.sub),
                        const SizedBox(width: 8),
                        Text(dateStr,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: AppColors.sub),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_plan['location'] ?? 'TBD',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description
                    const Text('About this plan',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      _plan['description']?.isNotEmpty == true
                          ? _plan['description']
                          : 'No description provided.',
                      style: const TextStyle(
                          color: AppColors.sub, height: 1.5, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // Participants Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Participants',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('$joined/$max',
                            style: TextStyle(
                                color: AppColors.sub,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Participants List
                    if (members.isEmpty)
                      const Text('Be the first to join!',
                          style: TextStyle(color: AppColors.sub))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final mName = member['name'] as String? ?? 'User';
                          final mProf =
                              member['profession'] as String? ?? 'Explorer';
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.border,
                                child: Text(
                                  mName.isNotEmpty
                                      ? mName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  Text(mProf,
                                      style: const TextStyle(
                                          color: AppColors.sub, fontSize: 12)),
                                ],
                              ),
                              if (member['id'] == _plan['host_id']) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Host',
                                      style: TextStyle(
                                          color: AppColors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                )
                              ]
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border:
                    Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: _buildCTA(
                  isHost: isHost, hasJoined: hasJoined, isFull: isFull),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTA(
      {required bool isHost, required bool hasJoined, required bool isFull}) {
    if (isHost) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openPlanChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('💬 Open Chat',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _handleDelete,
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: _loading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        color: AppColors.rose, strokeWidth: 2))
                : const Text('Cancel this plan',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }

    if (hasJoined) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openPlanChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('💬 Open Chat',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _handleLeave,
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: _loading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        color: AppColors.rose, strokeWidth: 2))
                : const Text('Leave this plan',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isFull || _loading ? null : _handleJoin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          disabledBackgroundColor: AppColors.border,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                isFull ? 'Plan is Full' : '🙋 Join Plan — Free',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white),
              ),
      ),
    );
  }
}
