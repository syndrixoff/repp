import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _MicroPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final bool enabled;

  const _MicroPress({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.enabled = true,
  });

  @override
  State<_MicroPress> createState() => _MicroPressState();
}

class _MicroPressState extends State<_MicroPress> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || (widget.onTap == null && widget.onLongPress == null)) {
      return;
    }
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          scale: _isPressed ? 0.97 : 1,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _isPressed ? 0.92 : 1,
            child: ClipRRect(
              borderRadius: widget.borderRadius ?? BorderRadius.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism container with translucent background and no blur.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  // Kept for API compatibility; blur is intentionally not applied.
  final double blur;
  final double opacity;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.color,
    this.border,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled =
        Theme.of(context).scaffoldBackgroundColor == AppColors.oledBackground;

    final effectiveColor =
        color ?? AppColors.getGlassBackground(isDark: isDark, isOled: isOled);

    final effectiveBorderColor = AppColors.getGlassBorder(
      isDark: isDark,
      isOled: isOled,
    );

    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border:
                border ?? Border.all(color: effectiveBorderColor, width: 1.5),
            boxShadow: boxShadow,
            gradient: gradient,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A glassmorphism card widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final bool enabled;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 10.0,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.width,
    this.height,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4),
      padding: padding ?? const EdgeInsets.all(16),
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      blur: blur,
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      return _MicroPress(
        onTap: onTap,
        onLongPress: onLongPress,
        enabled: enabled,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }
}

/// A glassmorphism button widget
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
    this.blur = 8.0,
    this.borderRadius,
    this.width,
    this.height,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled =
        Theme.of(context).scaffoldBackgroundColor == AppColors.oledBackground;

    final effectiveBackgroundColor =
        backgroundColor ??
        AppColors.getGlassBackground(isDark: isDark, isOled: isOled);

    final effectiveBorderColor = AppColors.getGlassBorder(
      isDark: isDark,
      isOled: isOled,
    );

    return _MicroPress(
      onTap: isLoading ? null : onPressed,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            padding:
                padding ??
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              border: Border.all(color: effectiveBorderColor, width: 1.5),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor ?? AppColors.primary,
                        ),
                      ),
                    )
                  : DefaultTextStyle(
                      style: TextStyle(
                        color:
                            foregroundColor ??
                            (isDark ? Colors.white : AppColors.lightTextPrimary),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      child: child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism icon button
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final double blur;
  final Color? iconColor;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 48,
    this.iconSize = 24,
    this.blur = 8.0,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled =
        Theme.of(context).scaffoldBackgroundColor == AppColors.oledBackground;

    final effectiveBackgroundColor = AppColors.getGlassBackground(
      isDark: isDark,
      isOled: isOled,
    );

    final effectiveBorderColor = AppColors.getGlassBorder(
      isDark: isDark,
      isOled: isOled,
    );

    final effectiveIconColor =
        iconColor ?? (isDark ? Colors.white : AppColors.lightTextPrimary);

    Widget button = _MicroPress(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(size / 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: effectiveBorderColor, width: 1.5),
            ),
            child: Center(
              child: Icon(icon, size: iconSize, color: effectiveIconColor),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

/// A glassmorphism chip widget
class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool selected;
  final Color? selectedColor;
  final double blur;

  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.onDeleted,
    this.selected = false,
    this.selectedColor,
    this.blur = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled =
        Theme.of(context).scaffoldBackgroundColor == AppColors.oledBackground;

    final effectiveSelectedColor = selectedColor ?? AppColors.primary;

    final backgroundColor = selected
        ? effectiveSelectedColor.withValues(alpha: 0.3)
        : AppColors.getGlassBackground(isDark: isDark, isOled: isOled);

    final borderColor = selected
        ? effectiveSelectedColor.withValues(alpha: 0.5)
        : AppColors.getGlassBorder(isDark: isDark, isOled: isOled);

    final textColor = selected
        ? const Color(0xFF1A1A1A)
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return _MicroPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onDeleted != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDeleted,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism navigation bar
class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavigationBarItem> items;
  final double blur;
  final double height;

  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.blur = 15.0,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled =
        Theme.of(context).scaffoldBackgroundColor == AppColors.oledBackground;

    final backgroundColor = AppColors.getGlassBackground(
      isDark: isDark,
      isOled: isOled,
    );

    final borderColor = AppColors.getGlassBorder(
      isDark: isDark,
      isOled: isOled,
    );

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == currentIndex;

                return _GlassNavigationBarItemWidget(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onTap(index),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation bar item data
class GlassNavigationBarItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const GlassNavigationBarItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

class _GlassNavigationBarItemWidget extends StatelessWidget {
  final GlassNavigationBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassNavigationBarItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = isSelected
        ? const Color(0xFF1A1A1A)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return _MicroPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A glassmorphism floating action button
class GlassFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final double blur;
  final bool extended;

  const GlassFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
    this.blur = 10.0,
    this.extended = false,
  });

  @override
  Widget build(BuildContext context) {
    return _MicroPress(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(extended ? 28 : 56),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(extended ? 28 : 56),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            height: 56,
            padding: EdgeInsets.symmetric(horizontal: extended ? 20 : 16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(extended ? 28 : 56),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF1A1A1A), size: 24),
                if (extended && label != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    label!,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glassmorphism app bar
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double blur;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.blur = 15.0,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled =
        Theme.of(context).scaffoldBackgroundColor == AppColors.oledBackground;

    final backgroundColor = AppColors.getGlassBackground(
      isDark: isDark,
      isOled: isOled,
    );

    final borderColor = AppColors.getGlassBorder(
      isDark: isDark,
      isOled: isOled,
    );

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: kToolbarHeight,
                  child: NavigationToolbar(
                    leading:
                        leading ??
                        (automaticallyImplyLeading && Navigator.canPop(context)
                            ? IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.pop(context),
                              )
                            : null),
                    middle:
                        titleWidget ??
                        (title != null
                            ? Text(
                                title!,
                                style: Theme.of(context).textTheme.titleLarge,
                              )
                            : null),
                    trailing: actions != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!,
                          )
                        : null,
                    centerMiddle: true,
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
