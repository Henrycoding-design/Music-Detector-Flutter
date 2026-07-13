import 'package:flutter/material.dart';

class GlowingLoadingIndicator extends StatefulWidget {
  final String title;
  final String? subtitle;

  const GlowingLoadingIndicator({
    super.key,
    this.title = "Recognizing song...",
    this.subtitle = "This may take up to 2 minutes for some URLs.",
  });

  @override
  State<GlowingLoadingIndicator> createState() => _GlowingLoadingIndicatorState();
}

class _GlowingLoadingIndicatorState extends State<GlowingLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Creates a smooth ease-in-out breathing curve
    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        // Calculate dynamic values based on the animation pulse (between 0.0 and 1.0)
        final blurRadius = 4.0 + (_glowAnimation.value * 12.0);
        final opacity = 0.4 + (_glowAnimation.value * 0.6);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Circular Indicator
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4 * _glowAnimation.value),
                      blurRadius: blurRadius,
                      spreadRadius: _glowAnimation.value * 4,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      primaryColor.withValues(alpha: opacity),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Pulsing Informative Text
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor.withValues(alpha: opacity),
                ),
              ),
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6 * opacity),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}