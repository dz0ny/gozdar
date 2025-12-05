import 'package:flutter/material.dart';
import '../models/navigation_target.dart';

/// Banner displayed at top of map showing active navigation target
class NavigationTargetBanner extends StatelessWidget {
  final NavigationTarget target;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const NavigationTargetBanner({
    super.key,
    required this.target,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 70, // Leave space for FAB buttons
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.navigation, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        target.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Tapni za kompas',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                  tooltip: 'Prekliči navigacijo',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
