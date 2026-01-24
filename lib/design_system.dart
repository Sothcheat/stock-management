import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final bool showBack;

  const SoftScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.actions,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoftColors.background,
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: SoftColors.textMain.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: SoftColors.textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: SoftColors.textMain,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            // Main Content
            Expanded(child: body),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
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
    // "Glow" shadow color based on background or primary
    final shadowColor = (color ?? SoftColors.brandPrimary).withValues(
      alpha: 0.15,
    );

    Widget card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? SoftColors.surface,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SoftColors.textMain.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        maxLines: widget.maxLines,
        readOnly: widget.readOnly,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        style: GoogleFonts.outfit(color: SoftColors.textMain, fontSize: 16),
        decoration: InputDecoration(
          labelText: widget.labelText,
          labelStyle: GoogleFonts.outfit(color: SoftColors.textSecondary),
          hintText: widget.hintText,
          hintStyle: GoogleFonts.outfit(
            color: SoftColors.textSecondary.withValues(alpha: 0.7),
          ),
          prefixIcon: widget.prefixIcon != null
              ? ValueListenableBuilder<bool>(
                  valueListenable: _isFocused,
                  builder: (context, isFocused, child) {
                    final icon = isFocused && widget.activePrefixIcon != null
                        ? widget.activePrefixIcon
                        : widget.prefixIcon;
                    final color = isFocused
                        ? SoftColors.brandPrimary
                        : SoftColors.textSecondary;

                    return Icon(icon, color: color);
                  },
                )
              : null,
          prefixText: widget.prefixText,
          prefixStyle: GoogleFonts.outfit(
            color: SoftColors.textMain,
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
                          icon: const Icon(
                            Icons.cancel, // Use cancel or clear
                            color: SoftColors.textSecondary,
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
            color: SoftColors.textMain,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
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
  final Duration duration;
  final double scaleFactor;

  const BounceButton({
    super.key,
    required this.child,
    required this.onTap,
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
    return BounceButton(
      onTap: isLoading ? () {} : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor ?? SoftColors.brandPrimary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? SoftColors.brandPrimary).withValues(
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
