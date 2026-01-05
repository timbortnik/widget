# Design Principles

This document captures the design philosophy guiding the Meteogram app UI.

## Core Philosophy

> "Simplicity is not the absence of clutter... it's about bringing order to complexity."
> — Jony Ive

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

### 2. Visual Hierarchy Through Content

The most important information should be the most prominent. Not through decoration, but through space and scale.

**Hierarchy (top to bottom):**
1. Location (functional, tappable)
2. Temperature (hero, large)
3. Chart (the core value)

### 3. Flatten Visual Nesting

Avoid card-within-card patterns. Each level of visual nesting adds cognitive load.

```
Before:                          After:
┌─────────────────────┐         ┌─────────────────────┐
│  1°                 │         │  1°                 │
│  Now                │         │                     │
│  ┌───────────────┐  │         │  ☀ Max 8%          │
│  │ ☀ Max 8%     │  │   →     │  💧 Max 2.7 mm     │
│  │ 💧 Max 2.7mm │  │         │                     │
│  └───────────────┘  │         │                     │
└─────────────────────┘         └─────────────────────┘
```

### 4. Consistent Visual Language

- One corner radius throughout (20dp for cards)
- Consistent spacing rhythm
- Color from theme, not hardcoded

### 5. Trust the Platform

- Use pull-to-refresh (expected on mobile)
- Use system colors (Material You)
- Let system handle dark/light theming

### 6. Information on Demand

Not everything needs to be visible at once. Secondary information can be:
- Revealed on tap
- Shown in context
- Omitted entirely if derivable

## Layout Structure

```
┌────────────────────────────────────┐
│  📍 Location · Source ▼    🔄     │  ← Functional row
│                                    │
│  ┌────────────────────────────────┐│
│  │       1°                       ││  ← Hero content
│  │  ☀ Max 8%    💧 Max 2.7 mm    ││  ← Supporting stats
│  └────────────────────────────────┘│
│                                    │
│  ┌────────────────────────────────┐│
│  │     [METEOGRAM CHART]          ││  ← Core value
│  └────────────────────────────────┘│
└────────────────────────────────────┘
```

## Color Philosophy

- **No hardcoded colors** - All colors from theme or Material You
- **System background** - Widget uses `?android:attr/colorBackground`
- **Transparent chart PNG** - Renders on system background
- **Theme-aware** - Different palettes for light/dark, automatically applied

See `lib/theme/app_theme.dart` for implementation.

## When Adding Features

Before adding a UI element, ask:

1. **Is it necessary?** Can the user understand without it?
2. **Does it earn its space?** What value does it add?
3. **Can it be simpler?** Is there a more minimal way?
4. **Does it follow hierarchy?** Is prominence proportional to importance?
5. **Is it consistent?** Does it match existing patterns?

## References

- [Dieter Rams: 10 Principles of Good Design](https://www.vitsoe.com/us/about/good-design)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Material Design 3](https://m3.material.io/)
