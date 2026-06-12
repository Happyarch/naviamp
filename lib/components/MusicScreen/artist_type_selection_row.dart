import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finamp_models.dart';

class ArtistTypeSelectionRow extends ConsumerWidget {
  final TabContentType tabType;
  final ArtistType defaultArtistType;
  final void Function(TabContentType) refreshTab;

  const ArtistTypeSelectionRow({
    super.key,
    required this.tabType,
    required this.defaultArtistType,
    required this.refreshTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox.shrink();
  }
}
