import 'package:flutter/material.dart';

/// A section metadata used for scroll-to navigation.
class SectionEntry {
  const SectionEntry({
    required this.title,
    required this.sectionKey,
    this.icon,
  });

  final String title;
  final GlobalKey sectionKey;
  final IconData? icon;
}

/// A popup menu button that lists all sections of a scrollable screen.
/// Tapping a section name scrolls the [ScrollController] to that section's
/// position by finding the [GlobalKey]'s render box.
class SectionScrollMenu extends StatelessWidget {
  const SectionScrollMenu({
    super.key,
    required this.sections,
    required this.scrollController,
  });

  final List<SectionEntry> sections;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Jump to section',
      onSelected: (String title) {
        for (final SectionEntry entry in sections) {
          if (entry.title == title) {
            _scrollToSection(context, entry.sectionKey);
            return;
          }
        }
      },
      itemBuilder: (BuildContext context) {
        return sections.map(
          (SectionEntry entry) {
            return PopupMenuItem<String>(
              value: entry.title,
              child: Row(
                children: <Widget>[
                  if (entry.icon != null) ...<Widget>[
                    Icon(entry.icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                  ],
                  Text(entry.title),
                ],
              ),
            );
          },
        ).toList(growable: false);
      },
    );
  }

  void _scrollToSection(BuildContext context, GlobalKey key) {
    final BuildContext? sectionContext = key.currentContext;
    if (sectionContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.08, // 0.08 = a small top padding from the edge
    );
  }
}

