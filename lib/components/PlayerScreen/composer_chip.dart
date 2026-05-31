import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../models/jellyfin_models.dart';
import '../../screens/artist_screen.dart';

const _borderRadius = BorderRadius.all(Radius.circular(4));

/// Shows per-composer chips for a track.  Each chip with a known Navidrome
/// artist ID navigates to the existing ArtistScreen; chips without an ID are
/// non-tappable labels.  Falls back to displaying displayComposer as a single
/// non-tappable chip when composerItems is absent.
class ComposerChips extends StatelessWidget {
  const ComposerChips({super.key, required this.baseItem, this.backgroundColor, this.color});

  final BaseItemDto baseItem;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final composers = baseItem.composerItems;
    final displayComposer = baseItem.displayComposer;

    if ((composers == null || composers.isEmpty) && (displayComposer == null || displayComposer.isEmpty)) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];

    if (composers != null && composers.isNotEmpty) {
      for (final composer in composers) {
        chips.add(_ComposerChip(
          name: composer.name,
          composerId: composer.id,
          backgroundColor: backgroundColor,
          color: color,
        ));
      }
    } else if (displayComposer != null) {
      chips.add(_ComposerChip(
        name: displayComposer,
        composerId: null,
        backgroundColor: backgroundColor,
        color: color,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: chips,
        ),
      ),
    );
  }
}

class _ComposerChip extends StatelessWidget {
  const _ComposerChip({required this.name, required this.composerId, this.backgroundColor, this.color});

  final String? name;
  final String? composerId;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? AppLocalizations.of(context)!.unknownArtist;
    final bgColor = backgroundColor ?? Colors.white.withValues(alpha: 0.1);
    final fgColor = color ?? Theme.of(context).textTheme.bodySmall?.color ?? Colors.white;

    final composerItem = composerId != null
        ? BaseItemDto(id: BaseItemId(composerId!), name: name, type: 'MusicArtist')
        : null;

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: "$displayName (Composer)", button: composerItem != null),
      excludeSemantics: true,
      container: true,
      child: Material(
        color: bgColor,
        borderRadius: _borderRadius,
        child: InkWell(
          borderRadius: _borderRadius,
          onTap: composerItem != null
              ? () => Navigator.of(context).pushNamed(ArtistScreen.routeName, arguments: composerItem)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(color: fgColor),
            ),
          ),
        ),
      ),
    );
  }
}
