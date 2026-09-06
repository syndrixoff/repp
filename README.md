# Repp - Workout Tracker & Exercise Library

A cross-platform workout tracking app built with Flutter, featuring a comprehensive exercise library with high-quality videos, routine planning, progress tracking, and personal records.

## Features

- **📱 Cross-Platform**: Runs on Android, iOS, Windows, macOS, Linux, and Web
- **🏋️ Exercise Library**: 300+ exercises with HQ videos and thumbnails
- **📋 Workout Routines**: Create and save custom workout routines
- **⏱️ Active Workout Tracking**: Track sets, reps, and weights in real-time
- **📊 Progress Charts**: Visualize your fitness journey
- **🏆 Personal Records**: Automatic PR detection and tracking
- **📈 One Rep Max Calculator**: Estimate your 1RM from any lift
- **💾 Local Storage**: All data stored locally on your device

## Screenshots

The app features a clean, modern UI inspired by popular fitness apps:

- **Workout Tab**: Quick start workouts or use saved routines
- **Exercise Library**: Search and filter exercises by muscle group and equipment
- **Active Workout**: Log sets with weight and reps, track completion
- **History**: View past workouts and statistics
- **Profile**: Track streaks, view all-time stats, manage settings

## Getting Started

### Prerequisites

- Flutter SDK 3.11.0 or higher
- Dart 3.11.0 or higher

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/repp.git
cd repp
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
# For development
flutter run

# For specific platform
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

### Building for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Web
flutter build web --release
```

## Project Structure

```
lib/
├── main.dart              # App entry point and theme configuration
├── models/                # Data models
│   ├── exercise.dart      # Exercise model
│   ├── workout.dart       # Workout, WorkoutExercise, WorkoutSet models
│   ├── personal_record.dart # PR model and 1RM calculator
│   └── models.dart        # Barrel export
├── providers/             # State management (Provider)
│   ├── workout_provider.dart   # Active workout state
│   ├── routine_provider.dart   # Routines management
│   └── history_provider.dart   # Workout history and stats
├── screens/               # UI screens
│   ├── home_screen.dart          # Main navigation
│   ├── workout_tab.dart          # Workout/routines list
│   ├── active_workout_screen.dart # In-progress workout
│   ├── exercise_picker_screen.dart # Exercise selection
│   ├── create_routine_screen.dart  # Routine builder
│   ├── exercises_tab.dart        # Exercise library
│   ├── exercise_detail_screen.dart # Exercise details with video
│   ├── history_tab.dart          # Workout history
│   └── profile_tab.dart          # Profile and settings
├── services/              # Business logic
│   ├── database_service.dart  # SQLite database operations
│   └── exercise_service.dart  # Exercise loading and search
├── widgets/               # Reusable widgets
└── utils/                 # Utility functions
```

## Tech Stack

- **Framework**: Flutter 3.11+
- **State Management**: Provider
- **Local Database**: SQLite (sqflite)
- **Media**: Video Player, Cached Network Image
- **Charts**: FL Chart
- **Other**: CSV parsing, UUID generation

## Exercise Data

Exercise metadata is bundled in `assets/data/exercises.csv`.
Media URLs and thumbnails are resolved from the app's configured media pipeline.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
Third-party attribution and notices are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Acknowledgments

- Exercise videos and thumbnails from Hevy API
- Inspired by popular fitness apps like Hevy, Strong, and JEFIT

## Roadmap

- [ ] Rest timer with notifications
- [ ] Workout templates from community
- [ ] Cloud sync and backup
- [ ] Social features and sharing
- [ ] Apple Watch / Wear OS support
- [ ] Plate calculator
- [ ] Body measurements tracking
- [ ] Nutrition tracking integration