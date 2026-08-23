import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

class NeoCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final Color shadowColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const NeoCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.shadowColor = AppColors.ink,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = const BorderRadius.all(Radius.circular(kRadius)),
  });

  @override
  State<NeoCard> createState() => _NeoCardState();
}

class _NeoCardState extends State<NeoCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: interactive ? (_) => setState(() => _down = true) : null,
      onTapUp: interactive ? (_) => setState(() => _down = false) : null,
      onTapCancel: interactive ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: _down ? Matrix4.translationValues(3, 3, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: widget.borderRadius,
          border: Border.all(color: AppColors.ink, width: kBorderWidth),
          boxShadow: _down || !interactive
              ? const []
              : [
                  BoxShadow(
                    color: widget.shadowColor,
                    offset: kShadow,
                    blurRadius: 0,
                  ),
                ],
        ),
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

class NeoButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? emoji;
  final Color color;
  final VoidCallback? onTap;
  final bool expanded;
  final double minHeight;

  const NeoButton({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    this.color = AppColors.yellow,
    this.onTap,
    this.expanded = true,
    this.minHeight = kTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: minHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (emoji != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(emoji!, style: const TextStyle(fontSize: 22)),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(icon, size: 24, color: AppColors.ink),
            ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
    return NeoCard(
      onTap: onTap,
      color: color,
      padding: EdgeInsets.zero,
      child: body,
    );
  }
}

class NeoIconSquare extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const NeoIconSquare({
    super.key,
    required this.icon,
    this.color = AppColors.yellow,
    this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      onTap: onTap,
      color: color,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(kRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.45, color: AppColors.ink),
      ),
    );
  }
}

class NeoBadge extends StatelessWidget {
  final String text;
  final Color color;

  const NeoBadge({super.key, required this.text, this.color = AppColors.yellow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String text;
  final String? emoji;

  const SectionHeader({super.key, required this.text, this.emoji});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class ConfidenceBar extends StatelessWidget {
  final double value;

  const ConfidenceBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    const segments = 10;
    final filled = (value * segments).round().clamp(0, segments);
    return Row(
      children: List.generate(segments, (i) {
        final isFilled = i < filled;
        return Expanded(
          child: Container(
            height: 18,
            margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: isFilled ? AppColors.green : Colors.white,
              border: Border.all(color: AppColors.ink, width: 1.6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String emoji;
  final String text;
  final String? hint;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.text,
    this.hint,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54),
              ),
            ],
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: 20),
              NeoButton(label: buttonLabel!, onTap: onButton),
            ],
          ],
        ),
      ),
    );
  }
}

void showNeoSheet(BuildContext context, Widget Function(BuildContext) builder) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: AppColors.ink, width: kBorderWidth),
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: builder,
  );
}
