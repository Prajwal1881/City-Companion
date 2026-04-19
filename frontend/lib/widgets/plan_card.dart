import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

const _catColors = {
  'food': Color(0xFFFF4D00),
  'play': Color(0xFF0057FF),
  'gym': Color(0xFF00C851),
  'ride': Color(0xFFFFAB00),
  'hangout': Color(0xFF7C3AED),
  'trek': Color(0xFF00A896),
};

const _catBg = {
  'food': Color(0xFFFFF1EC),
  'play': Color(0xFFEEF3FF),
  'gym': Color(0xFFEDFFF4),
  'ride': Color(0xFFFFFBEF),
  'hangout': Color(0xFFF5F0FF),
  'trek': Color(0xFFEDFAF8),
};

const _catEmoji = {
  'food': '🍜',
  'play': '🏏',
  'gym': '💪',
  'ride': '🏍️',
  'hangout': '☕',
  'trek': '🥾',
};

class PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final void Function(String id) onJoin;

  const PlanCard({super.key, required this.plan, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final cat = plan['category'] as String? ?? 'play';
    final color = _catColors[cat] ?? AppColors.orange;
    final bg = _catBg[cat] ?? const Color(0xFFEEF3FF);
    final emoji = _catEmoji[cat] ?? '🎯';
    final joined = (plan['joined_count'] as num?)?.toInt() ?? 0;
    final max = (plan['max_members'] as num?)?.toInt() ?? 10;
    final pct = max > 0 ? (joined / max).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Color stripe
        Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(21)),
              gradient: LinearGradient(colors: [color, color.withOpacity(0.5)]),
            )),
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Host row
            Row(children: [
              CircleAvatar(
                  radius: 17,
                  backgroundColor: color,
                  child: Text(
                    (plan['host_name'] as String? ?? 'U').substring(0, 1),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  )),
              const SizedBox(width: 10),
              Expanded(
                  child: RichText(
                      text: TextSpan(children: [
                TextSpan(
                    text: plan['host_name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 13)),
                const TextSpan(
                    text: ' is hosting',
                    style: TextStyle(color: AppColors.sub, fontSize: 13)),
              ]))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(99)),
                child: Text('$emoji ${cat[0].toUpperCase()}${cat.substring(1)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ]),
            const SizedBox(height: 10),

            // Title
            Text(plan['title'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.ink,
                  height: 1.25,
                )),
            const SizedBox(height: 4),

            // Desc
            Text(plan['description'] ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.sub,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),

            // Meta
            Wrap(spacing: 16, children: [
              _meta('⏰', plan['plan_date']?.toString().substring(0, 16) ?? ''),
              _meta('📍', plan['location'] ?? ''),
            ]),
            const SizedBox(height: 12),

            // Progress
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$joined/$max joined',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pct >= 1.0 ? AppColors.rose : AppColors.sub)),
              Text(pct >= 1.0 ? 'FULL' : '${(pct * 100).round()}%',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 14),

            // CTA
            _buildCTA(context,
                isHost: plan['is_host'] == true,
                hasJoined: plan['has_joined'] == true,
                pct: pct,
                color: color),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCTA(BuildContext context,
      {required bool isHost,
      required bool hasJoined,
      required double pct,
      required Color color}) {
    if (isHost) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.push('/plan/details', extra: plan),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('View Details',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white)),
        ),
      );
    }

    if (!hasJoined) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed:
              pct >= 1.0 ? null : () => onJoin(plan['id']?.toString() ?? ''),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: AppColors.border,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(
            pct >= 1.0 ? 'Plan is Full' : '🙋 Join Plan — Free',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
          ),
        ),
      );
    }

    // Has joined but not host
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => context.push('/plan/details', extra: plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('View Details',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              final convId = plan['conversation_id']?.toString();
              if (convId == null || convId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Chat thread not available yet')),
                );
                return;
              }
              context.go('/chat/$convId');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('💬 Chat',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _meta(String icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
    ]);
  }
}
