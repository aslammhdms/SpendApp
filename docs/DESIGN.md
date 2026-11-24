# SpendSheet design system

How SpendSheet looks, and how to build a new screen that fits. The tokens
live in `lib/core/theme/`; shared components live in `lib/shared/widgets/`.

## Principles

- **Calm by default, color for meaning.** Surfaces are near-neutral greys.
  Teal marks primary actions, selection and the Home hero. Green and red
  mean money in and money out; amber means a budget is close to its limit.
  Nothing else gets those colors.
- **Everything comes from the theme.** Widgets never use raw colors. Read
  `Theme.of(context).colorScheme`, `context.palette` and
  `Theme.of(context).textTheme`. Light and dark mode then come for free.
- **Numbers line up.** Every money amount uses tabular figures.
- **Solid content, glass chrome.** Cards, lists, charts and forms are solid:
  a card is a surface one tone off the page with a hairline border. Only the
  surfaces that float over content are frosted glass (see [Glass](#glass)).

## Color

### Scheme

`AppColorSchemes` (`app_color_schemes.dart`) builds both schemes. The accent
roles come from `ColorScheme.fromSeed(seedColor: #0E5A64, dynamicSchemeVariant:
fidelity)`, which keeps the brand teal saturated: primary is `#004149` in
light mode and `#91D1DC` in dark mode. To change the brand color, change the
seed.

The surface roles are set by hand to near-neutral greys. Seeded surfaces
carry the brand hue, which made the page, cards, fields and bars all tints of
one lavender.

| Surface role | Light | Dark | Use for |
| --- | --- | --- | --- |
| `surface` | `#F5F5F7` | `#0E0F12` | Page background (`scaffoldBackgroundColor`) |
| `surfaceContainerLow` | `#FFFFFF` | `#17181D` | Cards (the `Card` default), keypad keys |
| `surfaceContainer` | `#EFEFF2` | `#1C1D23` | Solid bars (what glass falls back to) |
| `surfaceContainerHigh` | `#E9E9EE` | `#25262D` | Text fields, chips, segmented tracks, neutral icon circles |
| `surfaceContainerHighest` | `#E1E1E7` | `#303139` | Progress-bar tracks |
| `palette.raisedSurface` | `#FFFFFF` | `#25262D` | Raised summary cards (Loans, Accounts) and the panel inside the hero |

Cards are separated from the page by their tone and by `palette.cardBorder`,
a hairline the `Card` theme draws. They have no elevation shadow.

Text on surfaces uses `onSurface`. Secondary text (dates, captions, hints)
uses `onSurfaceVariant`.

Selection (the navigation indicator, selected chips and segments) uses
`secondaryContainer` with `onSecondaryContainer`: a teal tint, `#D3ECEF` /
`#0A3F47` in light mode and `#103E45` / `#C6EEF2` in dark mode.

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
| `cardBorder` | `#E6E6EB` | `#24252B` | Hairline around cards and keypad keys |
| `hero`, `heroGlow`, `heroShade` | `#0D4F58` | same | The Home hero card (one flat color) and its month chip |
| `onHero`, `onHeroMuted` | `#FFFFFF`, `#ECEDFF` | same | Text on the hero |
| `glassBarTint`, `glassSheetTint`, `glassBorder` | white | `#17181D`, `#1C1D23` | Glass surfaces; use them through `GlassSurface` |
| `chart[0..7]`, `chartOther` | 8 hues + slate | lighter set | Chart series in order of size. Use `palette.chartColor(i)`. |

Every text color meets WCAG AA (4.5:1) on `surface`, `surfaceContainerLow`,
`surfaceContainer` and `surfaceContainerHigh` in its own mode. Every chart
color meets 3:1 against cards. `test/core/theme/contrast_test.dart` checks
all of this against the real theme, so add new colors to it.

**The hero** is the one place the brand color fills a surface. Its text is
`onHero` or `onHeroMuted`, which meet 4.5:1 on it. The card is one flat
color: no gradient and no highlights. Green and red would not be
readable there, so income and expense sit on a solid panel inside the card,
and "Over budget" is a solid red-tinted badge.

**Lists:** in a long list, show expense amounts in `onSurface` with a minus
sign and only income in green, so the list doesn't turn red. `MoneyText`
still announces "Expense" to screen readers. Summary cards keep the full
green and red signals.

**User colors:** category and account colors are part of the user's data,
saved in their spreadsheet. Draw them as they are (`CategoryIcon` tints with
them), offer `CategoryDefaults.pickerColors` in pickers, and use
`contrastOn(color)` for marks drawn on top of them.

## Glass

Frosted glass is for surfaces that float over content, and nothing else:

- the app bar, once content has scrolled under it (`GlassAppBar`)
- the bottom navigation bar (`AppBottomNav`)
- a pinned action bar (`GlassBottomBar`)
- bottom sheets (`showAppSheet`), dialogs (`AppAlertDialog`) and popup menus
  (`GlassMenuButton`)

All of them are built on one widget, `GlassSurface`, which blurs what is
behind it and lays a tint on top. The system date and time pickers and the
dropdown of a form field are left as Material draws them.

### Tokens

`Glass` in `tokens.dart`:

| Token | Value | Meaning |
| --- | --- | --- |
| `Glass.enabled` | `true` | Set to `false` to draw every glass surface solid |
| `Glass.blurSigma` | 20 | Blur of what is behind |
| `Glass.barTintOpacity` | 0.78 | Tint on bars, which carry only neutral text and icons |
| `Glass.sheetTintOpacity` | 0.92 | Tint on sheets, dialogs and menus, which can carry any text color |

The tint colors are `palette.glassBarTint` and `palette.glassSheetTint`.

### Why those opacities

Text on glass must meet AA whatever passes behind it. The opacities are
calculated for the worst backdrop there can be, pure black in light mode and
pure white in dark mode, which is harsher than any color the app or a
category can draw. Blur is ignored, which makes the figures conservative.

| | Minimum opacity (light / dark) | Chosen |
| --- | --- | --- |
| Bars: `onSurface` and `onSurfaceVariant` text at 4.5:1, status icons at 3:1 | 0.74 / 0.75 | 0.78 |
| Sheets: every text color in the palette at 4.5:1 | 0.90 / 0.91 | 0.92 |

Worst-case contrast at the chosen values:

| On glass | Light | Dark |
| --- | --- | --- |
| Bar title (`onSurface`) | 10.5 | 6.9 |
| Bar labels and icons (`onSurfaceVariant`) | 5.3 | 5.1 |
| Bar status icon, weakest color | 3.4 | 4.5 |
| Sheet text, weakest color | 4.8 | 4.8 |

`contrast_test.dart` recomputes these from the theme. Do not lower an
opacity below its minimum, and re-run the test if you change a tint or a
text color.

### Rules

- **Content must pass behind it.** Glass over a plain page is just a tint.
  Give the screen's `Scaffold` `extendBodyBehindAppBar: true` and pad its
  scrollable with `ScreenInsets.of(context)`, so the content fills the
  screen while the first and last rows still rest clear of the bars. The
  shell extends every tab under the navigation bar the same way.
- **Solid when asked.** `GlassSurface` draws its `solidColor` with no blur
  when `MediaQuery.highContrastOf(context)` is true (Increase Contrast on
  iOS, the contrast setting on Android 14 and later). Flutter exposes no
  "reduce transparency" setting; high contrast is the closest signal there
  is. Always pass the surface's ordinary color as `solidColor`.
- **One blur per surface, clipped to it.** `GlassSurface` clips the blur to
  its `borderRadius`. Never place one glass surface on another, and never
  put one inside a scrolling list item: each re-reads and blurs the pixels
  behind it on every frame.
- **Do not fade glass in with opacity.** Inside a fading layer the blur has
  nothing behind it. `GlassSurface.intensity` ramps the blur and tint
  instead (the app bar uses it); menus scale in.
- **Neutral text on bars.** Bars are see-through enough that only
  `onSurface`, `onSurfaceVariant` and status icons are safe on them. Put
  colored text on a sheet or on a solid surface.

Blur cost depends on the device's GPU and has not been measured on a phone.
If scrolling stutters on a low-end device, lower `Glass.blurSigma` or set
`Glass.enabled` to `false`.

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
- `Glass`: blur and tint opacities of glass surfaces (see [Glass](#glass)).

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
| `GlassSurface` | The frosted-glass background every glass surface is built on. |
| `GlassAppBar` | App bar that is clear at the top of the page and turns to glass once content scrolls under it. |
| `ScreenInsets` | Padding that keeps a scrollable's first and last rows clear of the glass bars. |
| `GlassBottomBar` | Pinned bar for a screen's main action (Save). |
| `showAppSheet` | Modal bottom sheet on glass, with the drag handle. Use it instead of `showModalBottomSheet`. |
| `AppAlertDialog` | Alert dialog on glass: title, message, actions. Use it instead of `AlertDialog`. |
| `GlassMenuButton` | Icon button that opens a small menu on glass. Use it instead of `PopupMenuButton`. |
| `SegmentedControl` | "Pick one of a few": a rounded block that slides along a rounded track. |

Material components (`Card`, `FilledButton`, chips, list tiles, snack bars,
tooltips, text fields, switches) are styled in `AppTheme`, so use them
plainly. Sheets, dialogs and menus go through the glass widgets above, which
also draw the sheet's drag handle; don't draw another.

## Patterns

- **Screen:** `Scaffold(extendBodyBehindAppBar: true)` on `surface` with a
  `GlassAppBar` (centered title). Pad the scrollable with
  `ScreenInsets.of(context)`, called with the screen's own `context`; pass
  `bottom: Space.fabClearance` under a floating button and `appBarBottom:`
  when the app bar has a `bottom`. A `RefreshIndicator` takes
  `edgeOffset: ScreenInsets.topOf(context)`. A screen that does not scroll
  (Add Transaction) keeps a normal body under the same app bar.
- **Hero card (Home only):** `palette.hero` (flat), radius `xl`, text in
  `onHero` / `onHeroMuted`, signals on a solid `raisedSurface` panel.
- **Summary card (Loans, Accounts):** `raisedSurface`, radius `xl`,
  `cardShadow`. A neutral headline amount, then `SignalStat`s.
- **List of items:** group rows in a `Card` under an `OverlineHeader`. Rows
  are at least 64 dp tall: `CategoryIcon`, title (`titleSmall`), second line
  (`bodySmall`, `onSurfaceVariant`), `MoneyText` on the right.
- **Floating button:** wrap it in `AutoHideFab`, listen to scrolling with
  `NotificationListener<UserScrollNotification>(onNotification:
  visibility.onScroll)`, and pad the list's bottom by `Space.fabClearance`.
- **Full-screen pages** (forms, details) are `GoRoute`s with
  `parentNavigatorKey: _rootNavigatorKey`, so they cover the bottom navigation.
- **Picking one of a few:** `SegmentedControl` (Analytics period). The type
  tabs on Add Transaction are a `TabBar` in the same shape: a track of
  `surfaceContainerHigh` with radius `md`, 48 dp tall, and a selected block
  with radius `sm`.
- **Amount entry:** `AmountInputPad`. The amount sits in a card that takes
  the free space; the keys are card-colored with a hairline, the delete key a
  tone darker. The whole cell of a key is tappable.
- **Pinned action:** `GlassBottomBar` as the `bottomNavigationBar`, holding
  one full-width `FilledButton`.
- **Sheets, dialogs, menus:** `showAppSheet`, `AppAlertDialog` (inside
  `showDialog`), `GlassMenuButton`. They open above the bottom navigation.
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
- Touch targets are at least 48 dp (the theme sets this for buttons;
  segments and keypad keys are tappable over their whole cell).
- Text and icons on glass meet the same ratios over any backdrop, and glass
  turns solid under the system high-contrast setting.
- Every `IconButton` has a `tooltip`; amounts use `MoneyText` or a
  `Semantics` label that says what the number is.
- Meaning never depends on color alone: signs, arrows, labels.
- Check the screen at 1.3× text size (all screens were checked at 1.3x for
  overflow). Let long labels ellipsize rather than wrap mid-number.
- Haptics: `selectionClick` on choices, `lightImpact` on keypad keys,
  `mediumImpact` on a successful save.

## Building a new screen

1. Use the Material component the theme already styles, or the shared widget
   in the table above, before making a custom one.
2. Colors from `colorScheme` or `context.palette`, text from `textTheme`,
   numbers from `Space` / `Radii` / `Motion` / `Sizes`.
3. Amounts through `MoneyText`; icons for categories through `CategoryIcon`.
   Sheets, dialogs and menus through the glass widgets; glass nowhere else.
4. Check light and dark mode, and 1.3× text.
5. Widget tests can wrap the widget in a plain `MaterialApp`:
   `context.palette` falls back to a palette built from the active scheme.
