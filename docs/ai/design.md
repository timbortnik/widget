# Design Principles

This document captures the design philosophy guiding the Meteogram app UI.

## Core Philosophy

> "Simplicity is not the absence of clutter... it's about bringing order to complexity."
> — Jony Ive

> "People think focus means saying yes to the thing you've got to focus on. But that's not what it means at all. It means saying no to the hundred other good ideas."
> — Steve Jobs

The app follows minimalist design principles: every element must earn its place, content should speak for itself, and we trust the user's intelligence.

## Guiding Principles

### 1. Remove the Unnecessary

If something can be understood without being stated, don't state it.

| Removed | Rationale |
|---------|-----------|
| App title in header | User knows what app they opened |
| "Now" label under temperature | Current temp is obviously "now" |
| "Updated X min ago" banner | Secondary metadata competing for attention |
| "46-Hour Forecast" label | The chart speaks for itself |
| Refresh button | Pull-to-refresh exists; trust the platform |
| "Max 8%" / "Max 2.7mm" stats | Redundant with chart; replaced with simple legend |

### 2. Visual Hierarchy Through Content

The most important information should be the most prominent. Not through decoration, but through space and scale.

**Hierarchy (top to bottom):**
1. Location (functional, tappable, small)
2. Temperature (hero, large, colored)
3. Legend (unobtrusive, explains chart)
4. Chart (the core value, fills space)

### 3. Unify Related Data

Data that belongs together should feel like one element. Avoid artificial separation.

```
Before:                          After:
┌─────────────────────┐         ┌─────────────────────┐
│  1°     ☀️💧       │         │  1°        ☀️ 💧   │
│  Now                │         │                     │
└─────────────────────┘         │  ╭────────────╮     │
                                │  │   CHART    │     │
┌─────────────────────┐    →    │  ╰────────────╯     │
│     [CHART]         │         │                     │
└─────────────────────┘         └─────────────────────┘
   Two separate cards              One unified card
```

### 4. Color as Data Connection

Use color purposefully to connect related information:

- **Temperature text** uses the same color as the **temperature line** on the chart
- **Legend icons** use the same colors as their **chart elements** (yellow sun = daylight bars, teal drop = precipitation bars)

This creates intuitive visual links without explanation.

### 5. Consistent Visual Language

- One corner radius throughout (20dp for cards)
- Consistent spacing rhythm (16dp between elements)
- Color from theme, not hardcoded
- Single card contains all weather data

### 6. Trust the Platform

- Use pull-to-refresh (expected on mobile, no button needed)
- Use system colors (Material You)
- Let system handle dark/light theming
- Widget background uses `?android:attr/colorBackground`

### 7. Legend for Occasional Users

The widget is viewed daily; the app is opened occasionally. When users open the app, they may have forgotten what the colors mean.

Keep the legend (Daylight, Precipitation) but make it unobtrusive:
- Small text, secondary visual weight
- Positioned near the chart it describes
- Icons colored to match chart elements

### 8. Chart Tooltip Above, Not Under Finger

When tapping the chart to see details, the tooltip appears **above the chart** in a fixed position:
- User's finger doesn't obscure the information
- Tooltip is outside the ShaderMask fade effect (always fully visible)
- Shows: time, temperature, daylight %, precipitation
- Icons colored (☀ yellow, 💧 blue), text uniform color
- All values localized (time format, units)

## Layout Structure

```
┌────────────────────────────────────┐
│  📍 Location · Source ▼            │  ← Tappable, opens picker
│                                    │
│  ┌────────────────────────────────┐│
│  │  12°        ☀️ Daylight       ││  ← Temp + legend
│  │             💧 Precipitation   ││
│  │                                ││
│  │  3 PM  5°  ☀ 42%  💧 1.2 mm/h ││  ← Tooltip (on tap)
│  │  ╭────────────────────────╮   ││
│  │  │                        │   ││  ← Chart
│  │  │    [METEOGRAM]         │   ││
│  │  │                        │   ││
│  │  ╰────────────────────────╯   ││
│  └────────────────────────────────┘│
│                                    │
│  (space for attribution/footer)    │
└────────────────────────────────────┘
```

## Color Philosophy

- **No hardcoded colors** - All colors from theme or Material You
- **System background** - Widget uses `?android:attr/colorBackground`
- **Transparent chart PNG** - Renders on system background
- **Theme-aware** - Different palettes for light/dark, automatically applied
- **Semantic color** - Temperature text matches temperature line

See `lib/theme/app_theme.dart` for implementation.

## When Adding Features

Before adding a UI element, ask:

1. **Is it necessary?** Can the user understand without it?
2. **Does it earn its space?** What value does it add?
3. **Can it be simpler?** Is there a more minimal way?
4. **Does it follow hierarchy?** Is prominence proportional to importance?
5. **Is it consistent?** Does it match existing patterns?
6. **Can it be unified?** Should it merge with an existing element?

## References

- [Dieter Rams: 10 Principles of Good Design](https://www.vitsoe.com/us/about/good-design)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Material Design 3](https://m3.material.io/)
