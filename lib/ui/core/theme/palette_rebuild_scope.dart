import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// Rebuilds routed screens when palette or brightness changes.
///
/// [AppColors] reads static getters; widgets that already built keep old [Color]
/// values until [build] runs again. Tab shells ([StatefulShellRoute]) keep
/// offstage branches mounted, so wrap each route screen with [paletteAware].
class PaletteRebuildScope extends ConsumerWidget {
  const PaletteRebuildScope({super.key, required this.builder});

  final Widget Function(AppColorPalette palette, Brightness brightness) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final brightness = ref.watch(brightnessProvider);
    AppColors.setPalette(palette);
    AppColors.setBrightness(brightness);
    return builder(palette, brightness);
  }
}

Widget paletteAware(Widget Function() buildScreen) {
  return PaletteRebuildScope(builder: (_, _) => buildScreen());
}
