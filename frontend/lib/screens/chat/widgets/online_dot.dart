import 'package:flutter/material.dart';

class OnlineDot extends StatelessWidget {
  final bool isOnline;
  final double size;
  final double borderSize;

  const OnlineDot({
    Key? key,
    required this.isOnline,
    this.size = 14.0,
    this.borderSize = 2.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOnline)
      return const SizedBox
          .shrink(); // Hide if offline, or use grey dot if preferred

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF188038), // Google Workspace Green
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context)
              .scaffoldBackgroundColor, // Seamless integration with background
          width: borderSize,
        ),
      ),
    );
  }
}

// Usage Example inside a Stack:
// Stack(
//   children: [
//     CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl)),
//     Positioned(
//       right: 0, bottom: 0,
//       child: OnlineDot(isOnline: user.isOnline),
//     )
//   ]
// )
