# Privacy Policy

**Effective Date:** January 8, 2025

**Meteogram Widget** ("the App") is developed by Tim Bortnik. This Privacy Policy explains how the App collects, uses, and protects your information.

## Summary

- The App collects location data only to show weather for your area
- All data is stored locally on your device
- No personal data is sent to our servers (we don't have any)
- Weather data is fetched from Open-Meteo, a privacy-friendly weather API

## Information We Collect

### Location Data

The App may collect location information in two ways:

1. **GPS Location** (optional): If you grant location permission, the App uses your device's GPS to determine your coordinates. This is used solely to fetch weather data for your current location.

2. **Manual Location**: You can manually search for and select a city. The city name and coordinates are stored locally on your device.

### How Location Data is Used

- To request weather forecast data from the Open-Meteo API
- To display your selected location name in the App and widget
- Location data is **never** sent to any server other than Open-Meteo for weather requests

### Data Stored on Your Device

The App stores the following data locally using Android SharedPreferences:

- Selected location coordinates (latitude/longitude)
- City name
- Location preference (GPS or manual)
- Recently searched cities (up to 5)
- Cached weather data (for offline access)
- Widget display preferences

This data never leaves your device except when coordinates are sent to Open-Meteo to fetch weather data.

## Third-Party Services

### Open-Meteo Weather API

The App uses [Open-Meteo](https://open-meteo.com/) to fetch weather data. When requesting weather:

- Your location coordinates are sent to Open-Meteo's servers
- Open-Meteo does not require an API key or user account
- Open-Meteo's privacy policy: https://open-meteo.com/en/terms

Open-Meteo is a privacy-focused weather API that:
- Does not track users
- Does not require personal information
- Only receives the coordinates necessary for the weather request

### Open-Meteo Geocoding API

When you search for a city, the search query is sent to Open-Meteo's Geocoding API to find matching locations. No personal information is included in these requests.

## Data We Do NOT Collect

- We do not collect personal information (name, email, phone number)
- We do not collect device identifiers
- We do not use analytics or tracking services
- We do not display advertisements
- We do not share any data with third parties (except weather requests to Open-Meteo)
- We do not have user accounts or registration

## Data Security

All data is stored locally on your device using Android's standard storage mechanisms. The App does not transmit any data to servers controlled by us because we do not operate any servers.

## Children's Privacy

The App does not knowingly collect any personal information from children under 13. The App does not require any personal information to function.

## Your Rights

Since all data is stored locally on your device, you have full control:

- **Access**: View your stored location in the App settings
- **Delete**: Clear the App's data through Android Settings, or uninstall the App
- **Modify**: Change your location at any time within the App

## Changes to This Policy

We may update this Privacy Policy from time to time. Changes will be posted in this document with an updated effective date. Continued use of the App after changes constitutes acceptance of the updated policy.

## Contact

If you have questions about this Privacy Policy, please open an issue at:

https://github.com/timbortnik/widget/issues

## Open Source

The App's source code is available under the Business Source License at:

https://github.com/timbortnik/widget

You can review exactly what data the App collects and how it's used by examining the source code.

---

*This Privacy Policy was last updated on January 8, 2025.*
