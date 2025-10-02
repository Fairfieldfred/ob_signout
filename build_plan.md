OB Signout App - Build Plan
Project Overview
A Flutter/Dart mobile application for OB/GYN physicians to manage patient signouts during shift changes. The app prioritizes privacy by avoiding PHI (Protected Health Information) and uses local storage only with sharing capabilities via the share_plus package.

Core Requirements
Functional Requirements
Patient List Management
Display a list of patients with room number, initials, age, Gravida, Para, gestational age, Patient Type
Add, edit, and remove patients
Sort/filter patients by type (Labor, Postpartum, GYN Post-op, Consult)
Patient Details
Select individual patients to view/edit detailed parameters
Customizable data fields for each patient category
Track multiple clinical parameters per patient
Data Sharing
Export patient list and details at end of shift
Use share_plus package for system-native sharing
Format output as readable text (plain text or markdown)
Privacy & Security
No PHI storage (no full names, MRN, DOB, etc.)
Local storage only (no cloud/backend)
Data limited to initials and room number for identification
Non-Functional Requirements
Clean, intuitive UI suitable for busy clinical environment
Fast data entry (minimize taps/typing)
Offline-first (no internet required)
Cross-platform (iOS & Android)
Technical Architecture
Technology Stack
Framework: Flutter (latest stable)
Language: Dart
Local Storage: shared_preferences or hive for persistence
Sharing: share_plus package
State Management: Provider or Riverpod (recommended)
Data Model
dart
enum PatientType {
labor,
postpartum,
gynPostOp,
consult
}

class Patient {
String id; // UUID
String initials; // e.g., "JD"
String roomNumber; // e.g., "L&D 5"
PatientType type;
Map<String, dynamic> parameters; // Flexible key-value storage
DateTime createdAt;
DateTime updatedAt;
}
Project Structure
lib/
├── main.dart
├── models/
│ ├── patient.dart
│ └── patient_type.dart
├── services/
│ ├── storage_service.dart
│ └── share_service.dart
├── providers/
│ └── patient_provider.dart
├── screens/
│ ├── patient_list_screen.dart
│ ├── patient_detail_screen.dart
│ └── add_edit_patient_screen.dart
├── widgets/
│ ├── patient_card.dart
│ ├── parameter_input.dart
│ └── patient_type_selector.dart
└── utils/
├── constants.dart
└── formatters.dart
Build Phases
Phase 1: Project Setup & Core Structure
Goal: Initialize project with dependencies and basic architecture

Tasks:

Create new Flutter project: flutter create ob_signout
Add dependencies to pubspec.yaml:
yaml
dependencies:
flutter:
sdk: flutter
provider: ^6.1.0 # or riverpod
hive: ^2.2.3
hive_flutter: ^1.1.0
share_plus: ^7.2.0
uuid: ^4.0.0

dev_dependencies:
flutter_test:
sdk: flutter
hive_generator: ^2.0.0
build_runner: ^2.4.0
Set up project structure (create folders as outlined above)
Configure Hive for local storage initialization in main.dart
Deliverables:

Working Flutter app skeleton
Dependencies installed and configured
Project folder structure created
Phase 2: Data Models & Services
Goal: Implement core data structures and storage logic

Tasks:

Create Patient model class with:
All required fields
JSON serialization/deserialization
Hive type adapter (if using Hive)
Create PatientType enum
Implement StorageService:
CRUD operations for patients
Initialize local database
Retrieve all patients
Save/update/delete individual patient
Implement ShareService:
Format patient data for sharing
Use share_plus to export data
Generate human-readable text output
Deliverables:

models/patient.dart with complete model
services/storage_service.dart with persistence logic
services/share_service.dart with export functionality
Unit tests for data models
Phase 3: State Management
Goal: Set up app-wide state management

Tasks:

Create PatientProvider (or equivalent):
Load patients from storage on init
Add patient method
Update patient method
Delete patient method
Filter/sort patients by type
Expose patient list to UI
Integrate provider in main.dart
Deliverables:

providers/patient_provider.dart with full CRUD
Provider properly initialized in app root
Phase 4: Patient List Screen
Goal: Build main screen showing all patients

Tasks:

Create PatientListScreen:
AppBar with title and share button
ListView of patients
Floating action button to add new patient
Empty state when no patients
Create PatientCard widget:
Display initials, room number, patient type
Tap to navigate to detail screen
Swipe-to-delete or menu for delete option
Implement filtering by patient type (tabs or dropdown)
Wire up share button to ShareService
Deliverables:

screens/patient_list_screen.dart
widgets/patient_card.dart
Functional list view with navigation
Phase 5: Add/Edit Patient Screen
Goal: Create form for adding and editing patients

Tasks:

Create AddEditPatientScreen:
Form with validation
Input for initials (text field)
Input for room number (text field)
Patient type selector (dropdown or segmented control)
Save button
Cancel button
Implement form validation:
Initials required
Room number required
Prevent duplicate room numbers (optional)
Handle both "add" and "edit" modes
Integrate with PatientProvider to save data
Deliverables:

screens/add_edit_patient_screen.dart
Form validation logic
Integration with state management
Phase 6: Patient Detail Screen (Basic)
Goal: Display and edit individual patient parameters

Tasks:

Create PatientDetailScreen:
Display patient initials and room number
Edit button to modify basic info
Delete button
Section for clinical parameters
For now, implement a simple key-value parameter display:
Show existing parameters as list
Add new parameter button
Simple text input for keys and values
Wire up to PatientProvider for updates
Deliverables:

screens/patient_detail_screen.dart
Basic parameter management
Edit and delete functionality
Phase 7: Enhanced Parameter System
Goal: Create specialized parameter inputs based on patient type

Tasks:

Define parameter templates for each patient type:
Labor: Cervical dilation, station, contractions, epidural status, etc.
Postpartum: Delivery date/time, delivery type, estimated blood loss, complications, etc.
GYN Post-op: Surgery type, post-op day, drains/tubes, pain control, etc.
Consult: Primary service, reason for consult, recommendations, etc.
Create ParameterInput widget with different input types:
Text field
Number input
Dropdown/picker
Date/time picker
Toggle/checkbox
Dynamically render appropriate parameters based on patient type
Store parameters in Map<String, dynamic> format
Deliverables:

Parameter templates defined in utils/constants.dart
widgets/parameter_input.dart with multiple input types
Dynamic parameter rendering in detail screen
Phase 8: Share Formatting & Export
Goal: Create well-formatted signout text for sharing

Tasks:

Enhance ShareService to format data:
Group patients by type
Create readable sections
Format each patient with all parameters
Include timestamp of signout
Implement multiple format options:
Plain text
Markdown (optional)
Test sharing to common apps:
SMS
Email
Notes apps
Messaging apps
Deliverables:

Enhanced services/share_service.dart
Well-formatted signout output
Verified sharing functionality on iOS and Android
Phase 9: UI/UX Polish
Goal: Improve user experience and visual design

Tasks:

Implement consistent theming:
Color scheme appropriate for medical context
Clear visual hierarchy
Adequate touch targets for clinical use
Add loading states and error handling
Implement confirmation dialogs for destructive actions
Add animations/transitions (subtle, professional)
Ensure accessibility:
Sufficient color contrast
Semantic labels
Screen reader support
Test on various screen sizes
Deliverables:

Polished, professional UI
Consistent theme throughout app
Smooth animations and transitions
Phase 10: Data Persistence & App Lifecycle
Goal: Ensure data is properly saved and loaded

Tasks:

Test data persistence across app restarts
Implement automatic saving on changes
Handle app backgrounding/foregrounding
Add option to clear all data (with confirmation)
Test edge cases:
App crash recovery
Storage full scenarios
Rapid data entry
Deliverables:

Robust data persistence
Graceful handling of app lifecycle events
Data integrity maintained
Phase 11: Testing & Quality Assurance
Goal: Comprehensive testing before release

Tasks:

Write unit tests:
Models
Services
Providers
Write widget tests:
Key user flows
Form validation
List interactions
Perform manual testing:
End-to-end user flows
Edge cases
Cross-device testing (iOS and Android)
Performance testing:
Large patient lists
Quick data entry
Memory usage
Security review:
Verify no PHI leakage
Test sharing output for privacy
Deliverables:

Comprehensive test suite
Test coverage report
Bug-free, stable app
Phase 12: Documentation & Deployment Prep
Goal: Prepare for deployment and future maintenance

Tasks:

Write user documentation:
How to add patients
How to use parameters
How to share signout
Write developer documentation:
Code structure
Adding new parameter types
Extending functionality
Create app icons and splash screens
Prepare for app store submission:
Screenshots
App description
Privacy policy (emphasize no data collection)
Version 1.0 release preparation
Deliverables:

Complete documentation
App store assets ready
v1.0 ready for release
Future Enhancements (Post-v1.0)
Potential Features
Templates: Pre-filled parameter sets for common scenarios
History: Track patient updates over time during shift
Backup/Restore: Export/import patient list as JSON
Quick Actions: Shortcuts for common updates
Dark Mode: For overnight shifts
Voice Input: For hands-free parameter entry
Multiple Lists: Support for different units/services
Handoff Verification: Recipient can confirm receipt
Custom Parameters: User-defined parameter fields
Statistics: Track common issues/patterns over time
Privacy & Compliance Notes
Privacy Considerations
No PHI Storage: Only initials and room numbers stored
Local Only: No cloud sync, no analytics, no third-party services
User Responsibility: Users must ensure compliance with institutional policies
Disclaimer: Include disclaimer that app is not intended as sole medical record
Recommended App Disclaimer
This app is intended as a clinical communication tool only. It does not
replace official medical records or institutional signout systems. Users
are responsible for ensuring compliance with HIPAA and institutional
policies. Do not include full names, MRNs, or other identifying information
beyond initials and room numbers.
Development Timeline Estimate
Phase Estimated Time Priority
Phase 1: Setup 2-4 hours Critical
Phase 2: Models & Services 4-6 hours Critical
Phase 3: State Management 2-3 hours Critical
Phase 4: Patient List 4-6 hours Critical
Phase 5: Add/Edit Screen 3-4 hours Critical
Phase 6: Detail Screen 3-4 hours Critical
Phase 7: Parameters 6-8 hours High
Phase 8: Share Formatting 3-4 hours High
Phase 9: UI Polish 6-8 hours Medium
Phase 10: Persistence 2-3 hours High
Phase 11: Testing 8-10 hours High
Phase 12: Documentation 4-6 hours Medium
Total 47-66 hours
Note: Timeline assumes developer familiar with Flutter/Dart. Adjust as needed.

Getting Started with Claude Code
To begin development with Claude Code:

Save this document as BUILD_PLAN.md in your project root
Initialize the Flutter project: flutter create ob_signout
Navigate to project directory: cd ob_signout
Reference this plan when working with Claude Code
Work through phases sequentially
Update this document as requirements evolve
Success Criteria
The app will be considered successful when:

✅ Physicians can quickly add patients with minimal taps
✅ All relevant clinical parameters are captured
✅ Signout data is shareable in readable format
✅ No PHI is stored or transmitted beyond initials/room number
✅ App works reliably offline without cloud dependency
✅ UI is clean, intuitive, and usable in busy clinical setting
✅ Data persists across app restarts
✅ App is stable with no crashes or data loss
Document Version: 1.0
Last Updated: September 29, 2025
Project: OB Signout App
Platform: Flutter/Dart
