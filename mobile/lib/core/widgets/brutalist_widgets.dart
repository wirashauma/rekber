import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

/// Brutalist Card — Thick borders and hard offset shadows
class BrutalistCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double borderWidth;
  final double borderRadius;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BoxShape shape;

  const BrutalistCard({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.white,
    this.borderWidth = 3.0,
    this.borderRadius = 16.0,
    this.shadowOffset = const Offset(4, 4),
    this.padding,
    this.onTap,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
          shape: shape,
          border: Border.all(color: AppColors.black, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: AppColors.black,
              offset: shadowOffset,
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}


/// Brutalist Button — Interactive thick-bordered button
class BrutalistButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const BrutalistButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = AppColors.primary,
    this.textColor = AppColors.black,
    this.icon,
    this.isLoading = false,
    this.height = 56,
    this.width,
    this.padding,
    this.borderRadius = 12,
  });

  @override
  State<BrutalistButton> createState() => _BrutalistButtonState();
}

class _BrutalistButtonState extends State<BrutalistButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Stack(
        children: [
          // Shadow
          Container(
            height: widget.height,
            width: widget.width,
            margin: const EdgeInsets.only(left: 6, top: 6),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
          // Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            height: widget.height,
            width: widget.width,
            padding: widget.padding,
            margin: _isPressed 
                ? const EdgeInsets.only(left: 4, top: 4) 
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: AppColors.black, width: 3),
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.black),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: widget.textColor),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: widget.height < 45 ? 12 : 16,
                            fontWeight: FontWeight.w900,
                            color: widget.textColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brutalist Badge — Small text badge for status
class BrutalistBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Offset shadowOffset;

  const BrutalistBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    this.textColor = AppColors.black,
    this.shadowOffset = const Offset(3, 3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: AppColors.black, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.black,
            offset: shadowOffset,
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


/// Brutalist Skeleton Loading — Raw pulsing boxes
class BrutalistSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Offset shadowOffset;
  
  const BrutalistSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 0.0, // Brutalist: usually no rounding
    this.shadowOffset = const Offset(4, 4),
  });

  @override
  State<BrutalistSkeleton> createState() => _BrutalistSkeletonState();
}

class _BrutalistSkeletonState extends State<BrutalistSkeleton> {

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      period: const Duration(milliseconds: 1000),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        borderWidth: 3.0,
        borderRadius: widget.borderRadius,
        shadowOffset: widget.shadowOffset,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
        ),
      ),
    );
  }
}

/// Brutalist Bounce — Tactile scale animation for buttons
class BrutalistBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const BrutalistBounce({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
  });

  @override
  State<BrutalistBounce> createState() => _BrutalistBounceState();
}

class _BrutalistBounceState extends State<BrutalistBounce> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Animated Brutal Button — Tactile feedback with Neo-Brutalism styling
class AnimatedBrutalButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;

  const AnimatedBrutalButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = AppColors.white,
  });

  @override
  State<AnimatedBrutalButton> createState() => _AnimatedBrutalButtonState();
}

class _AnimatedBrutalButtonState extends State<AnimatedBrutalButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(color: AppColors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.black,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 24, color: AppColors.black),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brutalist Text Field — High contrast input with thick borders
class BrutalistTextField extends StatelessWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const BrutalistTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.black.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: Icon(prefixIcon, color: AppColors.black),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

