# Phase 1 Testing Guide

Quick reference for testing the new enhanced sharing features.

---

## Quick Test Checklist

### iOS Device Testing

- [ ] Build: `flutter run`
- [ ] Add 5 test patients
- [ ] Share → **Smart Share** (should recommend AirDrop)
- [ ] Verify AirDrop appears in share sheet
- [ ] Send to another iOS device
- [ ] Import file on recipient device
- [ ] Verify all 5 patients imported correctly

### Android Device Testing

- [ ] Build: `flutter run`
- [ ] Add 5 test patients
- [ ] Share → **Smart Share** (should recommend Nearby Share)
- [ ] Verify Nearby Share appears in share sheet
- [ ] Send to another Android device
- [ ] Import file on recipient device
- [ ] Verify all 5 patients imported correctly

### Cross-Platform Testing

- [ ] **Sender (any platform)**: Share → Smart Share → WiFi Transfer
- [ ] **Receiver (opposite platform)**: Import → Receive via nearby
- [ ] Verify device appears in list
- [ ] Connect and transfer
- [ ] Verify data integrity

---

## What to Look For

### ✅ Good Signs
- "Smart Share" appears at top of share menu with star icon
- Transfer method dialog shows with recommendations
- AirDrop (iOS) or Nearby Share (Android) is recommended
- Share sheet opens quickly
- Success message appears
- File imports correctly on recipient

### ⚠️ Potential Issues
- Dialog doesn't show methods
- Share sheet doesn't open
- File doesn't appear on recipient
- Import fails with error
- App crashes during transfer

---

## Common Test Scenarios

### Scenario 1: Same Platform (Happy Path)
1. Add patients on Device A
2. Tap Share → Smart Share
3. See recommended method (AirDrop/Nearby Share)
4. Select recommended method
5. Enter sender name
6. Choose Device B from share sheet
7. On Device B, open .obs file
8. Import patients

**Expected**: Fast, seamless transfer in ~5 seconds

### Scenario 2: Cross-Platform (WiFi)
1. Add patients on iOS device
2. Tap Share → Smart Share
3. See "WiFi Transfer" as an option
4. Select WiFi Transfer
5. Enter sender name
6. On Android device: Import → Receive via nearby
7. See iOS device in list
8. Tap to connect and transfer

**Expected**: Transfer completes in 1-2 seconds

### Scenario 3: User Cancellation
1. Start transfer (any method)
2. Cancel at sender name dialog
3. **Expected**: Returns to patient list, no error

OR

2. Cancel at method selection
3. **Expected**: Returns to patient list, no error

OR

2. (For native share) Close share sheet
3. **Expected**: App returns gracefully

### Scenario 4: No Patients
1. Delete all patients
2. Try to share
3. **Expected**: Error message "No patients to share"

---

## Device Setup Requirements

### iOS Devices
- iOS 13 or later (for AirDrop support)
- WiFi enabled
- Bluetooth enabled
- AirDrop receiving enabled:
  - Open Control Center
  - Long press network section
  - Tap AirDrop
  - Select "Everyone" or "Contacts Only"

### Android Devices
- Android 6.0 or later
- WiFi enabled
- Bluetooth enabled
- Location permission granted
- Google Play Services installed and updated
- Nearby Share enabled in Settings

---

## Troubleshooting Tests

### Test 1: AirDrop Not Appearing
**Setup**: Turn off Bluetooth on iOS device
**Action**: Try Smart Share → AirDrop
**Expected**: Share sheet still opens, but AirDrop greyed out or missing

**Then**: Turn Bluetooth back on
**Action**: Try again
**Expected**: AirDrop now appears

### Test 2: WiFi Transfer Without Network
**Setup**: Turn off WiFi on both devices
**Action**: Try Smart Share → WiFi Transfer
**Expected**: Advertising starts, but discovery fails (expected behavior)

**Note**: Log this as expected - will add better error message in future

### Test 3: Large Dataset
**Setup**: Add 50+ patients (use copy/paste to speed up)
**Action**: Smart Share → AirDrop/Nearby Share
**Expected**:
- Dialog shows larger data size
- Transfer may take longer but completes
- All patients import correctly

---

## Regression Testing

Ensure existing functionality still works:

- [ ] **Share as text** still works
- [ ] **Share as file** still works
- [ ] **Send via WiFi** (old option) still works
- [ ] **Paste data** import still works
- [ ] **Add/edit patient** still works
- [ ] **Delete patient** still works
- [ ] **Filter by type** still works

---

## Performance Benchmarks

Record these times for your test datasets:

| Dataset Size | AirDrop/Nearby | WiFi | Notes |
|--------------|----------------|------|-------|
| 5 patients (~10KB) | ___ sec | ___ sec | |
| 20 patients (~40KB) | ___ sec | ___ sec | |
| 50 patients (~100KB) | ___ sec | ___ sec | |

**Expected**:
- AirDrop/Nearby: 2-5 seconds (nearly instant)
- WiFi: 1-3 seconds

---

## Bug Report Template

If you find issues, document them like this:

```
**Issue**: [Brief description]

**Steps to Reproduce**:
1.
2.
3.

**Expected Behavior**:
[What should happen]

**Actual Behavior**:
[What actually happened]

**Device Info**:
- Platform: iOS/Android
- OS Version:
- App Version:
- Flutter Version: [run `flutter --version`]

**Screenshots/Logs**:
[Attach if available]

**Severity**: Critical / High / Medium / Low
```

---

## Test Report Template

After testing, fill this out:

```
## Phase 1 Test Report

**Tested By**:
**Date**:
**Devices Used**:
- Device 1: [iPhone 14, iOS 17.2]
- Device 2: [Pixel 6, Android 14]

### Test Results

#### Same-Platform (iOS AirDrop)
- [ ] PASS: Small dataset (5 patients)
- [ ] PASS: Medium dataset (20 patients)
- [ ] PASS: Large dataset (50+ patients)
- [ ] PASS: Cancellation handling
- [ ] PASS: Import on recipient

**Notes**:

#### Same-Platform (Android Nearby Share)
- [ ] PASS: Small dataset (5 patients)
- [ ] PASS: Medium dataset (20 patients)
- [ ] PASS: Large dataset (50+ patients)
- [ ] PASS: Cancellation handling
- [ ] PASS: Import on recipient

**Notes**:

#### Cross-Platform (WiFi)
- [ ] PASS: iOS → Android
- [ ] PASS: Android → iOS
- [ ] PASS: Device discovery
- [ ] PASS: Data integrity

**Notes**:

#### UI/UX
- [ ] PASS: Smart Share button visible
- [ ] PASS: Method dialog displays correctly
- [ ] PASS: Recommendations appropriate
- [ ] PASS: Icons and labels correct
- [ ] PASS: Error messages helpful

**Notes**:

### Performance

Average transfer times:
- AirDrop (5 patients): ___ sec
- Nearby Share (5 patients): ___ sec
- WiFi (5 patients): ___ sec

### Issues Found

[List any bugs, usability issues, or suggestions]

1.
2.
3.

### Overall Assessment

- [ ] Ready for beta release
- [ ] Needs minor fixes
- [ ] Needs major fixes
- [ ] Not ready

**Summary**:

**Recommendation**:
```

---

## Next Steps After Testing

### If All Tests Pass ✅
1. Fill out test report
2. Run `flutter build ios --release` (for iOS)
3. Run `flutter build apk --release` (for Android)
4. Upload to TestFlight / Google Play Internal Testing
5. Gather feedback from real users

### If Issues Found ⚠️
1. Document all issues with bug report template
2. Prioritize: Critical → High → Medium → Low
3. Fix critical and high severity issues
4. Re-test
5. Repeat until stable

### Performance Issues
If transfers are slower than expected:
1. Test on different WiFi networks
2. Check device Bluetooth/WiFi signal strength
3. Try with fewer patients first
4. Compare times to benchmarks above

---

## Getting Help

If you encounter issues during testing:

1. **Check flutter logs**: `flutter logs`
2. **Check device logs**:
   - iOS: Xcode → Devices → View Device Logs
   - Android: `adb logcat`
3. **Review implementation**: See PHASE1_IMPLEMENTATION_SUMMARY.md
4. **Check full plan**: See IMPLEMENTATION_PLAN.md

---

*Happy Testing!* 🚀
