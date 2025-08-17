# Changelog

## v9.5.2e (2025-08-17)

### Enhanced Continuous Tracking
- **Fresh GPS Timer**: Added automatic fresh GPS readings every 5 minutes (stationary) or 2 minutes (moving)
- **Movement-Adaptive Intervals**: Tracking frequency automatically adjusts based on movement detection
- **Enhanced Heartbeat**: Heartbeat now includes location data when available, ensuring regular server updates
- **Immediate GPS on Start**: Fresh GPS reading sent immediately when tracking starts
- **Improved Reliability**: Better handling of GPS failures with fallback to cached positions
- **Movement State Detection**: Automatic detection of movement state changes to optimize tracking intervals

### Technical Improvements
- Added `_freshGpsTimer` for regular fresh GPS readings regardless of movement
- Enhanced `_sendHeartbeat()` to include location data and battery information
- Improved `_handleStreamPosition()` with movement state change detection
- Added `_sendFreshGpsReading()` method that bypasses normal filtering rules
- Better error handling and fallback mechanisms for GPS failures

## v9.5.4 (2025-08-17)

### Removed
- Auto-enable tracking feature: removed automatic re-enabling of tracking when disabled
- Removed auto-enable tracking settings from both simple and advanced settings screens
- Removed notification when tracking was automatically re-enabled

## v9.5.3 (2025-08-03)

### Added
- Auto-enable tracking feature: automatically re-enables tracking if it gets disabled
- Added setting to control the auto-enable tracking feature in both simple and advanced settings screens
- Added notification when tracking is automatically re-enabled

## v9.5.2 (Previous version)

- Initial degoogled version
