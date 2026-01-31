import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';

/// **Soft Minimal Design System**
///
/// A cohesive collection of "Soft" UI components replacing standard Material 3.
/// - **Vibe:** Airy, friendly, premium.
/// - **Shapes:** High border radius (24px).
/// - **Shadows:** Colored "Glows" (high blur, low opacity).

class SoftColors {
  // Brand Identity (Preserved)
  static const Color brandPrimary = Color(0xFF3C67AC);

  // Soft Pastel Palette
  static const Color background = Color(
    0xFFF8F9FC,
  ); // Very light cool grey/blue
  static const Color surface = Colors.white;

  // Text Colors
  static const Color textMain = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF9094A6);

  // Soft Accents (Pastel versions of brand colors)
  static const Color accentBlue = Color(0xFFD2E4FF);
  static const Color accentPurple = Color(0xFFF2DAFF);
  static const Color accentOrange = Color(0xFFFFE5D2);

  // Status Colors (Softened)
  static const Color success = Color(0xFF81C784);
  static const Color error = Color(0xFFE57373);
  static const Color warning = Color(0xFFFFB74D);

  // Constants
  static const double cardRadius = 24.0;
  static const Color bgLight = Color(0xFFF0F4F9);
  static const Color bgSecondary = Color(0xFFEDF2F7);
  static const Color border = Color(0xFFE2E8F0);
  static const Color brandAccent = Color(0xFF5E81AC); // Complementary blue/grey
}

/// **SoftScaffold**
/// Replacement for default Scaffold.
/// Features:
/// - Custom "Floating Header" (no AppBar).
/// - Gradient/Soft background.
/// - Built-in SafeArea handling.
class SoftScaffold extends StatelessWidget {
  final String title;
  final Widget? titleWidget; // Added this
  final TextStyle? titleStyle;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final List<Widget>? actions;
  final bool showBack;

  const SoftScaffold({
    super.key,
    required this.title,
    this.titleWidget, // Added this
    required this.body,
    this.titleStyle,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet, // Initialize
    this.actions,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    // Access theme colors
    final colors = context.softColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Floating Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  if (showBack) ...[
                    BounceButton(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textMain.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: colors.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child:
                        titleWidget ??
                        Text(
                          title,
                          style:
                              titleStyle ??
                              GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: colors.textMain,
                                height: 1.1,
                              ),
                        ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            // Body
            Expanded(child: body),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet, // Use
    );
  }
}

/// **SoftCard**
/// A container with high border radius and soft shadows.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const SoftCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Access theme colors
    final colors = context.softColors;

    // "Glow" shadow color based on background or primary
    final shadowColor = (color ?? colors.brandPrimary).withValues(alpha: 0.15);

    Widget card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return BounceButton(onTap: onTap!, child: card);
    }

    return card;
  }
}

/// **ModernInput**
/// A borderless text field with soft background fill.
class ModernInput extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final IconData? activePrefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final String? suffixText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool showClearButton;
  final TextInputAction? textInputAction;

  const ModernInput({
    super.key,
    this.controller,
    this.focusNode,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.activePrefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.suffixText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.inputFormatters,
    this.onChanged,
    this.showClearButton = false,
    this.textInputAction,
  });

  @override
  State<ModernInput> createState() => _ModernInputState();
}

class _ModernInputState extends State<ModernInput> {
  late FocusNode _focusNode;
  late bool _isInternalFocusNode;
  final ValueNotifier<bool> _isFocused = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _isInternalFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    _isFocused.value = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant ModernInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (_isInternalFocusNode) {
        _focusNode.dispose();
      }

      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _isInternalFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _isInternalFocusNode = true;
      }
      _focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
    _isFocused.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Requested Fill Color for Inputs: #2A2D30 in Dark Mode
    final fillColor = isDark ? const Color(0xFF2A2D30) : colors.surface;
    final borderColor = isDark ? const Color(0xFF3A3C3E) : colors.border;

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      maxLines: widget.maxLines,
      readOnly: widget.readOnly,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      style: GoogleFonts.outfit(color: colors.textMain, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        labelText: widget.labelText,
        labelStyle: GoogleFonts.outfit(color: colors.textSecondary),
        hintText: widget.hintText,
        hintStyle: GoogleFonts.outfit(
          color: colors.textSecondary.withValues(alpha: 0.7),
        ),
        prefixIcon: widget.prefixIcon != null
            ? ValueListenableBuilder<bool>(
                valueListenable: _isFocused,
                builder: (context, isFocused, child) {
                  final icon = isFocused && widget.activePrefixIcon != null
                      ? widget.activePrefixIcon
                      : widget.prefixIcon;
                  final color = isFocused
                      ? colors.brandPrimary
                      : colors.textSecondary;

                  return Icon(icon, color: color);
                },
              )
            : null,
        prefixText: widget.prefixText,
        prefixStyle: GoogleFonts.outfit(
          color: colors.textMain,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        suffixIcon: widget.showClearButton && widget.controller != null
            ? ValueListenableBuilder<bool>(
                valueListenable: _isFocused,
                builder: (context, hasFocus, child) {
                  if (!hasFocus) return const SizedBox.shrink();
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller!,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => widget.controller!.clear(),
                      );
                    },
                  );
                },
              )
            : widget.suffixIcon,
        suffixText: widget.suffixText,
        suffixStyle: GoogleFonts.outfit(
          color: colors.textMain,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.brandPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}

/// **BounceButton**
/// Interactive button that scales down on tap.
class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Duration duration;
  final double scaleFactor;

  const BounceButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.duration = const Duration(milliseconds: 100),
    this.scaleFactor = 0.96,
  });

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(_controller);
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
    widget.onTap();
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
      onLongPress: widget.onLongPress, // Add this
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// **SoftButton** (Helper for standard prominent buttons)
class SoftButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;

  const SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;

    return BounceButton(
      onTap: isLoading ? () {} : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.brandPrimary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? colors.brandPrimary).withValues(
                alpha: 0.3,
              ),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: textColor ?? Colors.white, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// **SoftSliverScaffold**
/// A Sliver-based scaffolding for high-performance scrolling.
/// Features:
/// - Floating/Pinned/Snap Header
/// - Built-in pull-to-refresh support if needed (via RefreshIndicator wrapping body slivers if implemented)
/// - BouncingScrollPhysics
class SoftSliverScaffold extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget> slivers;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet; // Added
  final bool showBack;
  final List<Widget>? actions;
  final ScrollController? controller;

  const SoftSliverScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    required this.slivers,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet, // Added
    this.showBack = false,
    this.actions,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Sliver AppBar
            SliverAppBar(
              backgroundColor: colors.background,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 0,
              floating: true,
              pinned: true,
              snap: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 24,
              toolbarHeight: 80,
              title: Row(
                children: [
                  if (showBack) ...[
                    BounceButton(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textMain.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: colors.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child:
                        titleWidget ??
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colors.textMain,
                            height: 1.1,
                          ),
                        ),
                  ),
                ],
              ),
              actions: [
                if (actions != null) ...actions!,
                const SizedBox(width: 24), // Right padding
              ],
            ),

            // Content Slivers
            ...slivers,

            // Bottom Safe Area Spacer
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet, // Added
    );
  }
}

// ============================================================================
// SOUL & MOTION DESIGN SYSTEM
// Premium animations for a "living" UI experience
// ============================================================================

/// **SoftFadeInSlide**
/// A widget that fades in and slides up on first appearance.
/// Uses TweenAnimationBuilder for optimal performance.
///
/// Usage:
/// ```dart
/// SoftFadeInSlide(
///   index: itemIndex,
///   child: OrderCard(...),
/// )
/// ```
class SoftFadeInSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration staggerDelay;
  final double slideOffset;
  final Curve curve;

  const SoftFadeInSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 280),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.slideOffset = 50.0, // Increased from 30px for more personality
    this.curve = Curves.easeOutBack, // Spring effect
  });

  @override
  State<SoftFadeInSlide> createState() => _SoftFadeInSlideState();
}

class _SoftFadeInSlideState extends State<SoftFadeInSlide> {
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    // Mark as animated after first build to prevent re-animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasAnimated = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stagger delay based on index (capped at 10 items)
    final effectiveIndex = widget.index.clamp(0, 10);
    final delay = widget.staggerDelay * effectiveIndex;

    // If already animated, just show the child directly
    if (_hasAnimated) {
      return widget.child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: widget.duration + delay,
      curve: widget.curve,
      builder: (context, value, child) {
        // Apply stagger effect: delay the animation start
        final delayFraction =
            delay.inMilliseconds /
            (widget.duration.inMilliseconds + delay.inMilliseconds);
        final staggeredValue = delayFraction >= 1.0
            ? value
            : ((value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);

        // Clamp opacity to handle easeOutBack overshoot
        return Opacity(
          opacity: staggeredValue.clamp(0.0, 1.0),
          child: Transform.translate(
            // Allow slight overshoot on translation for spring effect
            offset: Offset(0, widget.slideOffset * (1 - staggeredValue)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// **SoftShimmer**
/// A shimmer loading placeholder that mimics card shapes.
/// Uses a LinearGradient with sweep animation.
class SoftShimmer extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;
  final int itemCount;
  final bool isCard;

  const SoftShimmer({
    super.key,
    this.height = 120,
    this.width = double.infinity,
    this.borderRadius = 16,
    this.itemCount = 3,
    this.isCard = true,
  });

  /// Creates a shimmer that mimics an OrderCard layout
  const SoftShimmer.orderCard({super.key, this.itemCount = 3})
    : height = 140,
      width = double.infinity,
      borderRadius = 16,
      isCard = true;

  /// Creates a shimmer that mimics a ProductCard layout
  const SoftShimmer.productCard({super.key, this.itemCount = 6})
    : height = 180,
      width = double.infinity,
      borderRadius = 16,
      isCard = true;

  /// Creates a shimmer that mimics a Sales Analysis daily row layout
  const SoftShimmer.dailyRow({super.key, this.itemCount = 5})
    : height = 72,
      width = double.infinity,
      borderRadius = 12,
      isCard = true;

  @override
  State<SoftShimmer> createState() => _SoftShimmerState();
}

class _SoftShimmerState extends State<SoftShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.itemCount, (index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                height: widget.height,
                width: widget.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + (_controller.value * 3), 0),
                    end: Alignment(-0.5 + (_controller.value * 3), 0),
                    colors: const [
                      Color(0xFFEEEEEE),
                      Color(0xFFF5F5F5),
                      Color(0xFFEEEEEE),
                    ],
                  ),
                ),
                child: widget.isCard ? _buildCardPlaceholder() : null,
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildCardPlaceholder() {
    // For smaller heights (dailyRow), use compact layout
    final isCompact = widget.height < 100;

    return Padding(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: isCompact
          ? Row(
              children: [
                // Left side - date placeholder
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                // Middle - text placeholders
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side - amount placeholder
                Container(
                  height: 20,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title placeholder
                Container(
                  height: 16,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle placeholder
                Container(
                  height: 14,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Spacer(),
                // Bottom row placeholders
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 12,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Container(
                      height: 20,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// **SoftListSwitcher**
/// An AnimatedSwitcher wrapper for lists that provides directional slide + fade transitions.
/// Uses RepaintBoundary for GPU isolation to prevent jitter during animations.
class SoftListSwitcher extends StatelessWidget {
  /// The child widget to animate (shimmer or real list)
  final Widget child;

  /// Unique key for the child (changes trigger animation)
  final Key childKey;

  /// Direction of navigation: positive = forward (slide from right), negative = backward (slide from left)
  final int direction;

  /// Duration of the transition
  final Duration duration;

  const SoftListSwitcher({
    super.key,
    required this.child,
    required this.childKey,
    this.direction = 1,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          // Stack allows simultaneous rendering of outgoing and incoming
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          // Directional slide: forward=slides from RIGHT, backward=slides from LEFT
          final slideOffset = direction > 0
              ? Tween<Offset>(
                  begin: const Offset(0.15, 0), // Enter from right
                  end: Offset.zero,
                )
              : Tween<Offset>(
                  begin: const Offset(-0.15, 0), // Enter from left
                  end: Offset.zero,
                );

          return SlideTransition(
            position: slideOffset.animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: KeyedSubtree(key: childKey, child: child),
      ),
    );
  }
}

/// **SoftAnimatedEmpty**
/// An animated empty state that fades and scales in gracefully.
class SoftAnimatedEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final Widget? action;

  const SoftAnimatedEmpty({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // Clamp opacity since easeOutBack can overshoot past 1.0
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + (0.2 * value.clamp(0.0, 1.0)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: colors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.outfit(
                color: colors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: GoogleFonts.outfit(
                  color: colors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// **softPageTransitionsBuilder**
/// Creates a smooth fade transition with easeInOutCubic curve.
/// Use for generic page transitions.
Widget softPageTransitionsBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeInOutCubic,
  );
  return FadeTransition(opacity: curvedAnimation, child: child);
}

/// **slideLeftTransitionsBuilder**
/// Slides new page from RIGHT to LEFT (forward navigation).
/// Use for moving forward in flows (e.g., list -> form).
Widget slideLeftTransitionsBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  );

  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero,
    ).animate(curvedAnimation),
    child: child,
  );
}

/// **scaleUpTransitionsBuilder**
/// Scales and fades in from center (0.95 -> 1.0).
/// Use for detail screens and modal-like presentations.
Widget scaleUpTransitionsBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutBack,
  );

  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
      child: child,
    ),
  );
}

/// Duration for soft page transitions (200ms)
const Duration softPageTransitionDuration = Duration(milliseconds: 200);

/// Duration for slide transitions (250ms)
const Duration slideTransitionDuration = Duration(milliseconds: 250);

/// Duration for scale up transitions (280ms)
const Duration scaleUpTransitionDuration = Duration(milliseconds: 280);

/// **showSoftDialog**
/// Shows a dialog with pop-up animation (0.8 -> 1.05 -> 1.0) and haptic feedback.
/// Use for confirmation dialogs like Void/Purge.
Future<T?> showSoftDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Pop-up effect: 0.8 -> 1.05 -> 1.0
      final scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.8,
            end: 1.05,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 70,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.05,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 30,
        ),
      ]).animate(animation);

      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      // Trigger haptic when fully open
      if (animation.status == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
      }

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(scale: scaleAnimation, child: child),
      );
    },
  );
}

/// **showSoftModalSheet**
/// Shows a modal bottom sheet with 90% height, rounded top corners, and drag-to-dismiss.
/// Use for modal flows like Create Order.
Future<T?> showSoftModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool enableDrag = true,
  double? height,
}) {
  HapticFeedback.mediumImpact();
  final colors = context.softColors;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    enableDrag: enableDrag,
    backgroundColor: colors.background,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SizedBox(
        height: height ?? MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content
            Expanded(child: builder(context)),
          ],
        ),
      );
    },
  );
}

/// **ErrorView**
/// A reusable error state with a soft illustration and retry button.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData? icon;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.softColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.cloud_off_rounded,
                size: 48,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Oops!",
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              BounceButton(
                onTap: onRetry!,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.brandPrimary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colors.brandPrimary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: colors.surface,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        retryLabel ?? "Retry",
                        style: GoogleFonts.outfit(
                          color: colors.surface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
