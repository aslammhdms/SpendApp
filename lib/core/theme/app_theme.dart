import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'app_color_schemes.dart';
import 'app_palette.dart';
import 'app_typography.dart';
import 'tokens.dart';

/// The app's light and dark themes, built from one function so the two
/// modes only differ in their [ColorScheme] and [AppPalette].
///
/// Widgets read colors from `Theme.of(context).colorScheme` and
/// `context.palette`, and text styles from `Theme.of(context).textTheme`.
abstract final class AppTheme {
  static ThemeData get light =>
      _build(AppColorSchemes.light, AppPalette.light(AppColorSchemes.light));

  static ThemeData get dark =>
      _build(AppColorSchemes.dark, AppPalette.dark(AppColorSchemes.dark));

  /// The theme for a scheme other than the brand's, such as one built on
  /// the phone's wallpaper color.
  static ThemeData fromScheme(ColorScheme scheme) => _build(
        scheme,
        scheme.brightness == Brightness.dark
            ? AppPalette.dark(scheme)
            : AppPalette.light(scheme),
      );

  static ThemeData _build(ColorScheme scheme, AppPalette palette) {
    final isDark = scheme.brightness == Brightness.dark;
    final text = AppTypography.textTheme.apply(
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    // Buttons are fully rounded.
    const buttonShape = StadiumBorder();
    const buttonSize = Size(64, Sizes.touchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: Space.xl);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [palette],
      appBarTheme: AppBarThemeData(
        // The page color at rest; the bar tone once content is under it.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? scheme.surfaceContainer
              : scheme.surface,
        ),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Space.xl,
        titleTextStyle: text.headlineSmall,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          // Where Android still draws its own navigation strip, match the
          // navigation bar above it.
          systemNavigationBarColor: scheme.surfaceContainer,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      // Cards: a surface set off from the page by its tone alone. No
      // border and no elevation shadow.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, Sizes.touchTarget),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(Sizes.touchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        border: const OutlineInputBorder(
          borderRadius: Radii.lgAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.lgAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.lgAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.lgAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.lgAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        extendedTextStyle: text.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontVariations: [
              FontVariation(
                  'wght', states.contains(WidgetState.selected) ? 700 : 500),
            ],
            overflow: TextOverflow.ellipsis,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        disabledColor: scheme.surfaceContainer,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle:
            text.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
        checkmarkColor: scheme.onSecondaryContainer,
        iconTheme: IconThemeData(size: 18, color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        labelPadding: const EdgeInsets.symmetric(horizontal: Space.sm),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide.none,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 40),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
        minVerticalPadding: Space.md,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: Sizes.progressBar,
        borderRadius: Radii.smAll,
        // The current Material look: a gap between the bar and its track.
        year2023: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        textStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: Radii.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      ),
    );
  }
}
