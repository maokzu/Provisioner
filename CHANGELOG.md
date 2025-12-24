# Provisioner - Changelog

## Version 1.1.0 (2024-12-24)

### New Features
- **Minimap Icon**: Added a clickable icon around the minimap for quick access
  - Left-click: Toggle tracker window
  - Right-click: Open manager window
  - Drag: Move icon around minimap (position saved)
- **ESC Key Support**: Manager and Guide windows now close when pressing ESC
- **Updated Load Message**: Changed startup message to inform users about `/prov` command

### Improvements
- Better user experience with minimap integration
- Consistent UI behavior with ESC key support
- Custom icon integration for better branding

### Technical
- Added minimap button with native WoW code (no external dependencies)
- Implemented UISpecialFrames registration for ESC key handling
- Added media folder with custom icon support

---

## Version 1.0.3 (Previous)

### Features
- Item tracking with drag-and-drop
- Goal setting for farming targets
- Visual and sound alerts on goal completion
- Character-specific or global tracking profiles
- Multiple accessibility themes (including colorblind-friendly options)
- English and French localization
- Import/Export functionality
- Interactive guide system
