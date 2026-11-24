# SpendSheet design system

How SpendSheet looks, and how to build a new screen that fits. The app
follows Material 3 Expressive: bold type, fully rounded buttons, connected
shapes, spring motion and tonal surfaces. The tokens live in
`lib/core/theme/`; shared components live in `lib/shared/widgets/`.

Material comes from the standalone `material_ui` package, not from
`package:flutter/material.dart`, which Flutter 3.50 deprecates. Import
`package:material_ui/material_ui.dart`.

## Principles

- **Bold where it counts, calm where you read.** Screen titles and headline
  amounts are large and heavy. Lists of amounts stay plain and easy to scan.
- **Color for meaning.** The primary color marks main actions, selection and
  the Home hero. Green and red mean money in and money out; amber means a
  budget is close to its limit. Nothing else gets those colors.
- **Everything comes from the theme.** Widgets never use raw colors. Read
  `Theme.of(context).colorScheme`, `context.palette` and
  `Theme.of(context).textTheme`. Light mode, dark mode and wallpaper colors
  then come for free.
- **Tone, not lines.** Surfaces are separated by their tone. There are no
  card borders, no elevation shadows on cards, and no blur.
- **Numbers line up.** Every money amount uses fixed-width digits.

## Color

### Scheme

`AppColorSchemes` (`app_color_schemes.dart`) builds every role from one seed
color with `ColorScheme.fromSeed`. The brand seed is deep teal, `#0E5A64`,
with the `fidelity` variant, which keeps it saturated: primary is `#004149`
in light mode and `#91D1DC` in dark mode.

**Wallpaper colors.** On Android 12 and later the user can switch on "Use
wallpaper colours" in Settings. The seed is then the wallpaper color the
phone reports (`dynamic_color`), and the whole scheme follows it
(`core/theme/wallpaper_colors.dart`). So never assume the primary color is
teal.

Surfaces are assigned by depth:

| Surface role | Use for |
| --- | --- |
| `surface` | Page background (`scaffoldBackgroundColor`), app bar at rest |
| `surfaceContainerLow` | Cards (the `Card` default), list tiles, sheets, keypad keys |
| `surfaceContainer` | Bars: bottom navigation, app bar once content is under it |
| `surfaceContainerHigh` | Text fields, chips, unselected buttons of a group, neutral icon circles, dialogs, menus |
| `surfaceContainerHighest` | Progress-bar tracks |
| `palette.raisedSurface` | The panel inside the Home hero; summary cards on Loans and Accounts |

In light mode the page is a soft grey and cards are the brightest tone; in
dark mode the page is the darkest tone and cards are a step lighter.
`AppColorSchemes._assign` maps the generated tones to these jobs.

Text on surfaces uses `onSurface`. Secondary text (dates, captions, hints)
uses `onSurfaceVariant`. Selection in the navigation bar and chips uses
`secondaryContainer` with `onSecondaryContainer`; the selected button of a
button group uses `primary` with `onPrimary`.

### App palette

`AppPalette` (`app_palette.dart`) is a `ThemeExtension` for colors Material
has no role for. Read it with `context.palette`.

| Token | Light | Dark | Use for |
| --- | --- | --- | --- |
| `income` | `#03694A` | `#34D399` | Money in, "owed to you" |
| `expense` | `#B91C1C` | `#F87171` | Money out, "you owe", deletes |
| `transfer` | primary | primary | Moves between your own accounts |
| `loan` | `#6D28D9` | `#C4B5FD` | Loans with people |
| `budgetSafe` / `Warning` / `Danger` | `#03694A` / `#A14A07` / `#B91C1C` | `#34D399` / `#FBBF24` / `#F87171` | Budget under 80%, from 80%, at 100% or more. Use `palette.budgetColor(used)`. |
| `*Container` / `on*Container` | soft tints | deep tints | Backgrounds of icon circles and type buttons, with text on them |
| `hero`, `onHero`, `onHeroMuted` | primary, onPrimary | primaryContainer, white | The Home hero card and its text |
| `chart[0..7]`, `chartOther` | 8 hues + slate | lighter set | Chart series in order of size. Use `palette.chartColor(i)`. |

Money colors are fixed: they do not follow the wallpaper.

Every text color meets WCAG AA (4.5:1) on `surface`, `surfaceContainerLow`,
`surfaceContainer` and `surfaceContainerHigh` in its own mode. Every chart
color meets 3:1 against cards. `test/core/theme/contrast_test.dart` checks
this against the real theme, so add new colors to it.

**The hero** is the one place the primary color fills a surface. It is one
flat color. Green and red would not be readable there, so income and expense
sit on a solid panel inside the card.

**Lists:** in a long list, show expense amounts in `onSurface` with a minus
sign and only income in green, so the list doesn't turn red. `MoneyText`
still announces "Expense" to screen readers. Summary cards keep the full
green and red signals.

**User colors:** category and account colors are part of the user's data,
saved in their spreadsheet. Draw them as they are (`CategoryIcon` tints with
them), offer `CategoryDefaults.pickerColors` in pickers, and use
`contrastOn(color)` for marks drawn on top of them.

## Typography

Roboto Flex, a variable font, is bundled in `assets/fonts/roboto_flex` in two
files: the first holds Latin, the second (family `Roboto Flex Ext`, used as a
fallback) adds currency signs and accented letters. A third one-character
font, `Dirham`, draws the UAE dirham sign (see [Currencies](#currencies)).

The scale lives in `AppTypography.textTheme` and sets no colors. Each style
sets the font's weight axis itself, and display and headline styles are also
set wider (112%).

| Role | Size / line height | Weight | Use for |
| --- | --- | --- | --- |
| `displayMedium` | 45 / 52 | 800, wide | Hero amount on Home |
| `displaySmall` | 36 / 44 | 800, wide | Amount entry, summary amounts |
| `headlineLarge` | 32 / 40 | 700, wide | |
| `headlineMedium` | 28 / 36 | 700, wide | Large amounts (net balance) |
| `headlineSmall` | 24 / 32 | 700 | App bar titles |
| `titleLarge` | 22 / 28 | 600 | Sheet and dialog titles, large card amounts |
| `titleMedium` | 16 / 24 | 600 | Card and section titles |
| `titleSmall` | 14 / 20 | 600 | List row titles, row amounts |
| `bodyLarge` / `bodyMedium` | 16 / 24, 14 / 20 | 400 | Body text |
| `bodySmall` | 12 / 16 | 400 | Second lines: dates, notes |
| `labelLarge` | 14 / 20 | 600 | Buttons, chips |
| `labelMedium` | 12 / 16 | 600 | Captions, badges, nav labels |
| `labelSmall` | 11 / 16 | 600 | Group headers ("Today") |

To change a style's weight, set `fontVariations` as well as `fontWeight`
(see the navigation labels in `AppTheme`); `fontWeight` alone does not move
a variable font's weight axis.

Money: `style.tabular` (an extension in `app_typography.dart`), or use
`MoneyText`, which does it for you.

### Currencies

`CurrencyUtils.format` puts the currency's symbol before the amount. AED uses
the dirham sign the Central Bank of the UAE introduced in 2025 (U+20C3).
Phone fonts do not have it yet, so only text drawn by the app can show it.
For text that leaves the app's font, pass `plain: true` (notifications) or
wrap the label in `CurrencyUtils.spoken` (screen-reader labels); both give
"AED 12.37".

## Spacing, shape, motion

From `tokens.dart`:

- `Space`: `xs` 4, `sm` 8, `md` 12, `lg` 16 (screen inset), `xl` 24 (card
  padding), `xxl` 32. `Space.fabClearance` (88) is the bottom padding of any
  list under a floating button.
- `Radii`: `xs` 4 (inner corners of connected shapes), `sm` 8 (chips,
  badges), `md` 12, `lg` 20 (text fields, outer corners of a segmented list,
  menus), `xl` 28 (cards, sheets, dialogs), `xxl` 36 (the hero). Buttons are
  fully round (`StadiumBorder`).
- `Motion`: `fast` 200 ms, `medium` 350 ms, `slow` 500 ms. Curves are
  springs: `spatial` (and `standard`, the same) and `spatialFast` overshoot
  a little and are for things that move or change shape; `effects` does not
  overshoot and is for fades and color. `countUp` (700 ms) is only for the
  hero amount. Animations that only decorate check
  `MediaQuery.disableAnimationsOf`.
- `Sizes`: `touchTarget` 48, `iconCircle` 40, `iconCircleSmall` 32,
  `progressBar` 8.

## Components

| Widget | What it is |
| --- | --- |
| `MoneyText` | An amount: formatted, tabular, colored by `MoneyKind`, announced as e.g. "Expense, $14.50". Pass `prefix: '-'` or `'+'`, and `color` to override. |
| `AnimatedMoney` | Hero amount that counts up, then animates between values. |
| `SignalStat` | Income/expense figure with a direction arrow in a tinted circle, for summary cards. |
| `CategoryIcon` | A category or account icon in a circle tinted with its color. Maps the stored emoji to a Material icon (`iconForEmoji`) and falls back to the emoji. |
| `SectionHeader` | Card title row with an optional "View All" action. |
| `OverlineHeader` | Small group label above cards ("Today", "People"). |
| `EmptyState` | Icon in a circle, title, optional subtitle and action; `compact` inside cards. |
| `SegmentedControl` | "Pick one of a few": a connected button group. The selected button fills with color and rounds all its corners. |
| `SegmentedList` | A group of rows drawn as connected tiles: large outer corners, small corners and a 2 dp gap between rows. |
| `AppLoader` | Loading indicator: a shape that turns while it morphs through Material shapes. Use it in place of a spinner. |
| `WavyProgressBar` | Progress whose filled part is a wave. For progress to feel good about (savings goals); budgets keep `LinearProgressIndicator`. |
| `AddMenuFab` | The Add button of the main screens: opens Expense, Income, Transfer and Loan. |
| `AutoHideFab` + `FabVisibility` | Floating button that slides away while you scroll down. |
| `ScreenInsets` | Padding that keeps a scrollable's first and last rows clear of the bars. |
| `BottomActionBar` | Pinned bar for a screen's main action (Save). |
| `showAppSheet` | Modal bottom sheet above the bottom navigation, with the drag handle. Use it instead of `showModalBottomSheet`. |
| `AppAlertDialog` | Alert dialog: title, message, actions that stack when they do not fit. Use it instead of `AlertDialog`. |
| `AppMenuButton` | Icon button that opens a small menu placed to stay on screen. Use it instead of `PopupMenuButton`. |

Material components (`AppBar`, `Card`, `FilledButton`, chips, list tiles,
snack bars, tooltips, text fields, switches, progress bars) are styled in
`AppTheme`, so use them plainly. The sheet theme draws the drag handle;
don't draw another.

`material_ui` does not have every Expressive component yet. `AppLoader`,
`WavyProgressBar`, `SegmentedControl`, `SegmentedList` and `AddMenuFab` are
built here to Material's specification. When the package gains its own,
replace ours.

## Patterns

- **Screen:** `Scaffold(extendBodyBehindAppBar: true)` on `surface` with an
  `AppBar` (title on the left, `headlineSmall`). The bar takes the bar tone
  once content scrolls under it. Pad the scrollable with
  `ScreenInsets.of(context)`, called with the screen's own `context`; pass
  `bottom: Space.fabClearance` under a floating button and `appBarBottom:`
  when the app bar has a `bottom`. A `RefreshIndicator` takes
  `edgeOffset: ScreenInsets.topOf(context)`. A screen that does not scroll
  (Add Transaction) keeps a normal body under the same app bar.
- **Hero card (Home only):** `palette.hero` (flat), radius `xxl`, amount in
  `displayMedium`, text in `onHero` / `onHeroMuted`, signals on a solid
  `raisedSurface` panel.
- **Summary card (Loans, Accounts):** `raisedSurface`, radius `xl`. A
  neutral headline amount, then `SignalStat`s.
- **List of rows that each open something** (transactions, settings,
  categories): a `SegmentedList` under an `OverlineHeader`. Rows are at
  least 64 dp tall: `CategoryIcon`, title (`titleSmall`), second line
  (`bodySmall`, `onSurfaceVariant`), `MoneyText` on the right.
- **Content that belongs together** (a chart, a budget, a summary): a `Card`.
- **Floating button:** wrap it in `AutoHideFab`, listen to scrolling with
  `NotificationListener<UserScrollNotification>(onNotification:
  visibility.onScroll)`, and pad the list's bottom by `Space.fabClearance`.
  On the main tabs the button is `AddMenuFab`.
- **Full-screen pages** (forms, details) are `GoRoute`s with
  `parentNavigatorKey: _rootNavigatorKey`, so they cover the bottom navigation.
- **Picking one of a few:** `SegmentedControl` (Analytics period, the type
  on Add Transaction, Expense / Income on Categories), in the app bar's
  `bottom` when it applies to the whole screen.
- **Amount entry:** `AmountInputPad`. The amount sits in a card that takes
  the free space; the keys are card-colored, the delete key a tone darker.
  The whole cell of a key is tappable.
- **Pinned action:** `BottomActionBar` as the `bottomNavigationBar`, holding
  one full-width `FilledButton`.
- **Loading:** `AppLoader` in the middle of the space. Keep the small
  `CircularProgressIndicator(strokeWidth: 2)` inside buttons.
- **Sheets, dialogs, menus:** `showAppSheet`, `AppAlertDialog` (inside
  `showDialog`), `AppMenuButton`. They open above the bottom navigation.
- **Choosing from a long list** (categories when adding a transaction): a
  strip of pills with the most used first, and an "All" pill that stays put
  and opens every option in a searchable grid (`showCategoryPicker`). Nothing
  should be more than two taps away.
- **Destructive actions:** red only in the confirming dialog's button, in
  menu items marked `destructive` and in swipe actions
  (`colorScheme.error`); the icon on the row stays neutral.

## Charts (fl_chart)

- Colors: `colorScheme.primary` for a single series, `palette.chart` by rank
  for categories, `palette.income` / `palette.expense` for in versus out.
- Bars have rounded tops (`Radii.sm`). Gridlines are horizontal only, dashed,
  in `outlineVariant` at 60%.
- Highlight today or the selected item with full color and dim the rest.
  Pair the color with something else too (a bold label, a marker).
- Tooltips: background `inverseSurface`, text `onInverseSurface`, numbers
  tabular.
- Axis labels: `labelSmall`, `onSurfaceVariant`, tabular figures.
- Give the chart a `Semantics` label that sums up what it shows.

## Accessibility checklist

- Text meets 4.5:1; icons and chart marks meet 3:1. The contrast tests run
  on the teal scheme; wallpaper schemes come from the same generator, which
  keeps Material's own contrast between each role and its "on" color.
- Touch targets are at least 48 dp (the theme sets this for buttons;
  buttons of a group and keypad keys are tappable over their whole cell).
- Every `IconButton` has a `tooltip`; amounts use `MoneyText` or a
  `Semantics` label that says what the number is, passed through
  `CurrencyUtils.spoken`.
- Meaning never depends on color alone: signs, arrows, labels.
- Springs and morphing stop when the system's "remove animations" setting is
  on (`MediaQuery.disableAnimationsOf`).
- Check the screen at 1.3× text size. Let long labels ellipsize rather than
  wrap mid-number.
- Haptics: `selectionClick` on choices, `lightImpact` on keypad keys,
  `mediumImpact` on a successful save.

## Building a new screen

1. Use the Material component the theme already styles, or the shared widget
   in the table above, before making a custom one.
2. Colors from `colorScheme` or `context.palette`, text from `textTheme`,
   numbers from `Space` / `Radii` / `Motion` / `Sizes`.
3. Amounts through `MoneyText`; icons for categories through `CategoryIcon`.
   Sheets, dialogs and menus through the app's own helpers.
4. Check light and dark mode, a wallpaper color, and 1.3× text.
5. Widget tests can wrap the widget in a plain `MaterialApp`:
   `context.palette` falls back to a palette built from the active scheme.
