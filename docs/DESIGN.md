# SpendSheet design system

How SpendSheet looks, and how to build a new screen that fits. The tokens
live in `lib/core/theme/`; shared components live in `lib/shared/widgets/`.

## Principles

- **Calm by default, color for meaning.** Surfaces are neutral. Green and red
  mean money in and money out; amber means a budget is close to its limit.
  Nothing else gets those colors.
- **Everything comes from the theme.** Widgets never use raw colors. Read
  `Theme.of(context).colorScheme`, `context.palette` and
  `Theme.of(context).textTheme`. Light and dark mode then come for free.
- **Numbers line up.** Every money amount uses tabular figures.
- **Depth through tone, not lines.** Cards are filled one step off the page;
  borders are rare.

## Color

### Scheme

`AppColorSchemes` (`app_color_schemes.dart`) builds both schemes with
`ColorScheme.fromSeed(seedColor: #6366F1, dynamicSchemeVariant: fidelity)`.
The fidelity variant keeps the brand indigo saturated: primary is `#4648D4`
in light mode and `#C0C1FF` in dark mode. To restyle the whole app, change
the seed.

| Surface role | Use for |
| --- | --- |
| `surface` | Page background (`scaffoldBackgroundColor`) |
| `surfaceContainerLow` | Cards (the `Card` default), details bars |
| `surfaceContainer` | Navigation bar |
| `surfaceContainerHigh` | Text fields, chips, segmented controls, neutral icon circles, dialogs |
| `surfaceContainerHighest` | Progress-bar tracks |
| `palette.raisedSurface` | Raised summary cards (Home, Loans, Accounts): white with a soft shadow in light mode, a lighter tone in dark mode |

Text on surfaces uses `onSurface`. Secondary text (dates, captions, hints)
uses `onSurfaceVariant`.

### App palette

`AppPalette` (`app_palette.dart`) is a `ThemeExtension` for colors Material
has no role for. Read it with `context.palette`.

| Token | Light | Dark | Use for |
| --- | --- | --- | --- |
| `income` | `#047552` | `#34D399` | Money in, "owed to you" |
| `expense` | `#B91C1C` | `#F87171` | Money out, "you owe", deletes |
| `transfer` | primary | primary | Moves between your own accounts |
| `loan` | `#6D28D9` | `#C4B5FD` | Loans with people |
| `budgetSafe` / `Warning` / `Danger` | `#047552` / `#A14A07` / `#B91C1C` | `#34D399` / `#FBBF24` / `#F87171` | Budget under 80%, from 80%, at 100% or more. Use `palette.budgetColor(used)`. |
| `*Container` / `on*Container` | soft tints | deep tints | Backgrounds of icon circles and tabs, with text on them |
| `chart[0..7]`, `chartOther` | 8 hues + slate | lighter set | Chart series in order of size. Use `palette.chartColor(i)`. |

Every text color meets WCAG AA (4.5:1) on `surface`, `surfaceContainerLow`
and `surfaceContainerHigh` in its own mode. Every chart color meets 3:1
against cards. If you add a color, check it the same way.

**Lists:** in a long list, show expense amounts in `onSurface` with a minus
sign and only income in green, so the list doesn't turn red. `MoneyText`
still announces "Expense" to screen readers. Summary cards keep the full
green and red signals.

**User colors:** category and account colors are part of the user's data,
saved in their spreadsheet. Draw them as they are (`CategoryIcon` tints with
them), offer `CategoryDefaults.pickerColors` in pickers, and use
`contrastOn(color)` for marks drawn on top of them.

## Typography

Inter is bundled in `assets/fonts/inter` (weights 400, 500, 600, 700), so it
renders the same offline. The scale lives in `AppTypography.textTheme` and
sets no colors.

| Role | Size / line height | Weight | Use for |
| --- | --- | --- | --- |
| `displaySmall` | 36 / 44 | 700 | Hero amount |
| `headlineMedium` | 28 / 36 | 700 | Large amounts (net balance, amount entry) |
| `headlineSmall` | 24 / 32 | 600 | Page-level headings |
| `titleLarge` | 20 / 28 | 600 | App bar titles, large card amounts |
| `titleMedium` | 16 / 24 | 600 | Card and section titles |
| `titleSmall` | 14 / 20 | 600 | List row titles, row amounts |
| `bodyLarge` / `bodyMedium` | 16 / 24, 14 / 20 | 400 | Body text |
| `bodySmall` | 12 / 16 | 400 | Second lines: dates, notes |
| `labelLarge` | 14 / 20 | 600 | Buttons, chips |
| `labelMedium` | 12 / 16 | 500 | Captions, badges, nav labels |
| `labelSmall` | 11 / 16 | 600, +0.6 tracking | Group headers ("Today") |

Money: `style.tabular` (an extension in `app_typography.dart`), or use
`MoneyText`, which does it for you.

## Spacing, shape, motion

From `tokens.dart`:

- `Space`: `xs` 4, `sm` 8, `md` 12, `lg` 16 (screen inset), `xl` 24 (card
  padding), `xxl` 32. `Space.fabClearance` (88) is the bottom padding of any
  list under a floating button.
- `Radii`: `sm` 8 (chips, badges, bars), `md` 12 (buttons, fields), `lg` 20
  (cards), `xl` 28 (hero cards, sheets, dialogs).
- `Motion`: `fast` 150 ms, `medium` 200 ms, `slow` 250 ms, `standard` curve
  `easeOutCubic`. `countUp` (700 ms) is only for the hero amount. Animations
  that only decorate check `MediaQuery.disableAnimationsOf`.
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
| `AutoHideFab` + `FabVisibility` | Floating button that slides away while you scroll down. |

Material components (`Card`, `FilledButton`, `SegmentedButton`, chips, list
tiles, sheets, dialogs, snack bars, tooltips, the navigation bar) are styled
in `AppTheme`, so use them plainly. Bottom sheets get their drag handle from
the theme; don't draw another.

## Patterns

- **Screen:** `Scaffold` on `surface`, centered title, content inset by
  `Space.lg`.
- **Summary card:** `raisedSurface`, radius `xl`, `cardShadow`. A neutral
  headline amount, then `SignalStat`s.
- **List of items:** group rows in a `Card` under an `OverlineHeader`. Rows
  are at least 64 dp tall: `CategoryIcon`, title (`titleSmall`), second line
  (`bodySmall`, `onSurfaceVariant`), `MoneyText` on the right.
- **Floating button:** wrap it in `AutoHideFab`, listen to scrolling with
  `NotificationListener<UserScrollNotification>(onNotification:
  visibility.onScroll)`, and pad the list's bottom by `Space.fabClearance`.
- **Full-screen pages** (forms, details) are `GoRoute`s with
  `parentNavigatorKey: _rootNavigatorKey`, so they cover the bottom navigation.
- **Choosing from a long list** (categories when adding a transaction): a
  strip of pills with the most used first, and an "All" pill that stays put
  and opens every option in a searchable grid (`showCategoryPicker`). Nothing
  should be more than two taps away.
- **Destructive actions:** red only in the confirming dialog's button and in
  swipe actions (`colorScheme.error`); the icon on the row stays neutral.

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

- Text meets 4.5:1; icons and chart marks meet 3:1.
- Touch targets are at least 48 dp (the theme sets this for buttons).
- Every `IconButton` has a `tooltip`; amounts use `MoneyText` or a
  `Semantics` label that says what the number is.
- Meaning never depends on color alone: signs, arrows, labels.
- Check the screen at 1.3× text size (all screens were checked at 1.3x for
  overflow). Let long labels ellipsize rather than wrap mid-number.
- Haptics: `selectionClick` on choices, `lightImpact` on keypad keys,
  `mediumImpact` on a successful save.

## Building a new screen

1. Use the Material component the theme already styles before making a custom one.
2. Colors from `colorScheme` or `context.palette`, text from `textTheme`,
   numbers from `Space` / `Radii` / `Motion` / `Sizes`.
3. Amounts through `MoneyText`; icons for categories through `CategoryIcon`.
4. Check light and dark mode, and 1.3× text.
5. Widget tests can wrap the widget in a plain `MaterialApp`:
   `context.palette` falls back to a palette built from the active scheme.
