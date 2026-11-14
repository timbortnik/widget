# Google Play Store Assets

This directory contains assets for the Google Play Store listing.

## Required Files

| File | Dimensions | Description |
|------|------------|-------------|
| `icon-512.png` | 512x512 | Hi-res app icon |
| `feature-graphic.png` | 1024x500 | Banner at top of store listing |
| `screenshots/*.png` | 1080x1920+ | Phone screenshots (min 2, max 8) |

## Optional Files

| File | Dimensions | Description |
|------|------------|-------------|
| `screenshots/tablet/*.png` | 1920x1080+ | Tablet screenshots |

## Text Content

The listing text (app name, short and full description, in every language) is
maintained only in Play Console — it is not kept in this repo. Limits: name 30,
short description 80, full description 4000 characters.

## Screenshot Tips

1. **Show the widget** - Main selling point is the home screen widget
2. **Multiple wallpapers** - Show widget works on light and dark backgrounds
3. **Light/dark mode** - Demonstrate theme adaptation
4. **Material You** - Show dynamic color theming if possible
5. **Clean home screen** - Don't clutter with too many other widgets

## Feature Graphic Tips

- Should be eye-catching and explain what the app does
- Consider showing a phone with the widget visible
- Keep text minimal (store listing has descriptions)
- Works well: gradient background + device mockup + simple tagline
