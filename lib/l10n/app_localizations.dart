import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
  ];

  static const _fallbackCode = 'en';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App & Navigation
      'appTitle': 'Repp',
      'home': 'Home',
      'workouts': 'Workouts',
      'exercises': 'Exercises',
      'quests': 'Quests',
      'history': 'History',
      'profile': 'Profile',
      
      // Profile & Settings
      'appearance': 'Appearance',
      'settings': 'Settings',
      'data': 'Data',
      'about': 'About',
      'language': 'Language',
      'selectLanguage': 'Select Language',
      'theme': 'Theme',
      'system': 'System',
      'light': 'Light',
      'dark': 'Dark',
      'oledDarkMode': 'OLED Dark Mode',
      'oledSubtitle': 'True black background for AMOLED screens',
      'units': 'Units',
      'metric': 'Metric (kg, km)',
      'imperial': 'Imperial (lbs, mi)',
      'restTimer': 'Rest Timer',
      'notifications': 'Notifications',
      'enabled': 'Enabled',
      'exportData': 'Export Data',
      'exportDataSubtitle': 'Export workouts as CSV',
      'importData': 'Import Data',
      'importDataSubtitle': 'Import from CSV',
      'clearAllData': 'Clear All Data',
      'clearAllDataSubtitle': 'Delete all workouts, routines, XP, and settings',
      'aboutRepp': 'About Repp',
      'privacyPolicy': 'Privacy Policy',
      'terms': 'Terms of Service',
      'rateApp': 'Rate App',
      'cancel': 'Cancel',
      'defaultRestTimer': 'Default Rest Timer',
      
      // Stats & Progress
      'allTimeStats': 'All-Time Stats',
      'volume': 'Volume',
      'sets': 'Sets',
      'reps': 'Reps',
      'weight': 'Weight',
      'distance': 'Distance',
      'currentStreak': 'Current Streak',
      'longestStreak': 'Longest Streak',
      'totalWorkouts': 'Total Workouts',
      'thisWeek': 'This Week',
      'thisMonth': 'This Month',
      
      // Quests
      'daily': 'Daily',
      'weekly': 'Weekly',
      'boss': 'Boss',
      'dailyReset': 'Daily Reset',
      'weeklyReset': 'Weekly Reset',
      'questsTitle': 'Quests',
      'questsSubtitle': 'Complete quests to earn XP and level up',
      'questCompleted': 'Quest Completed',
      'claimReward': 'Claim Reward',
      'claimed': 'Claimed',
      'progress': 'Progress',
      'xpReward': 'XP Reward',
      'reward': 'Reward',
      
      // XP System
      'xpTitle': 'Experience Points',
      'xpLevel': 'Level',
      'currentXp': 'Current XP',
      'nextLevel': 'Next Level',
      'totalXp': 'Total XP',
      'xpGained': 'XP Gained',
      'xpPerWorkout': 'XP per Workout',
      'bonus': 'Bonus',
      'bonusXp': 'Bonus XP',
      
      // Exercises
      'exercisesTitle': 'Exercises',
      'searchExercises': 'Search exercises...',
      'filter': 'Filter',
      'muscle': 'Muscle',
      'equipment': 'Equipment',
      'difficulty': 'Difficulty',
      'howTo': 'How To',
      'instructions': 'Instructions',
      'breathingTips': 'Breathing Tips',
      'commonMistakes': 'Common Mistakes',
      'variations': 'Variations',
      'exerciseDetail': 'Exercise Details',
      'primaryMuscles': 'Primary Muscles',
      'secondaryMuscles': 'Secondary Muscles',
      'beginner': 'Beginner',
      'intermediate': 'Intermediate',
      'advanced': 'Advanced',
      'push': 'Push',
      'pull': 'Pull',
      'legs': 'Legs',
      'core': 'Core',
      
      // Workouts
      'startWorkout': 'Start Workout',
      'endWorkout': 'End Workout',
      'activeWorkout': 'Active Workout',
      'workoutHistory': 'Workout History',
      'workoutDetails': 'Workout Details',
      'workoutComplete': 'Workout Complete',
      'congratulations': 'Congratulations!',
      'workoutTime': 'Workout Time',
      'totalVolume': 'Total Volume',
      'duration': 'Duration',
      'exercise': 'Exercise',
      'rest': 'Rest',
      'nextSet': 'Next Set',
      'skip': 'Skip',
      'finish': 'Finish',
      'resumeWorkout': 'Resume Workout',
      'deleteWorkout': 'Delete Workout',
      'editWorkout': 'Edit Workout',
      
      // Routines
      'routines': 'Routines',
      'createRoutine': 'Create Routine',
      'editRoutine': 'Edit Routine',
      'deleteRoutine': 'Delete Routine',
      'routineName': 'Routine Name',
      'selectExercises': 'Select Exercises',
      'addExercise': 'Add Exercise',
      'removeExercise': 'Remove Exercise',
      'scheduleRoutine': 'Schedule Routine',
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
      'selectDays': 'Select Days',
      'noRoutines': 'No routines yet',
      'createFirst': 'Create your first routine',
      
      // Messages
      'comingSoonNotifications': 'Notification settings coming soon!',
      'comingSoonExport': 'Export feature coming soon!',
      'comingSoonImport': 'Import feature coming soon!',
      'comingSoonPrivacy': 'Privacy policy coming soon!',
      'comingSoonTerms': 'Terms of service coming soon!',
      'clearDataSuccess': 'All app data cleared, including XP and settings.',
      'clearDataFailed': 'Failed to clear app data:',
      'thanksSupport': 'Thank you for your support!',
      'clearDataTitle': 'Clear All Data',
      'clearDataBody': 'This will permanently delete all app data, including workouts, routines, personal records, XP progress, and saved settings. This action cannot be undone.',
      'clearAll': 'Clear All',
      'noData': 'No data available',
      'loadingExercises': 'Loading exercises...',
      'error': 'Error',
      'errorLoading': 'Error loading data',
      'retry': 'Retry',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'close': 'Close',
      'confirm': 'Confirm',
      'no': 'No',
      'yes': 'Yes',
      'ok': 'OK',
      
      // Language Names
      'language_as': 'Assamese',
      'language_bn': 'Bengali',
      'language_brx': 'Bodo',
      'language_doi': 'Dogri',
      'language_en': 'English',
      'language_gu': 'Gujarati',
      'language_hi': 'Hindi',
      'language_kn': 'Kannada',
      'language_ks': 'Kashmiri',
      'language_kok': 'Konkani',
      'language_mai': 'Maithili',
      'language_ml': 'Malayalam',
      'language_mni': 'Manipuri (Meitei)',
      'language_mr': 'Marathi',
      'language_ne': 'Nepali',
      'language_or': 'Odia',
      'language_pa': 'Punjabi',
      'language_sa': 'Sanskrit',
      'language_sat': 'Santali',
      'language_sd': 'Sindhi',
      'language_ta': 'Tamil',
      'language_te': 'Telugu',
      'language_ur': 'Urdu',
    },
    // Machine translated labels (Google Translate style) for all UI.
    'hi': {
      // App & Navigation
      'appTitle': 'रेप',
      'home': 'होम',
      'workouts': 'वर्कआउट',
      'exercises': 'व्यायाम',
      'quests': 'मिशन',
      'history': 'इतिहास',
      'profile': 'प्रोफ़ाइल',
      
      // Profile & Settings
      'appearance': 'दिखावट',
      'settings': 'सेटिंग्स',
      'data': 'डेटा',
      'about': 'जानकारी',
      'language': 'भाषा',
      'selectLanguage': 'भाषा चुनें',
      'theme': 'थीम',
      'system': 'सिस्टम',
      'light': 'हल्का',
      'dark': 'अंधकार',
      'oledDarkMode': 'OLED डार्क मोड',
      'oledSubtitle': 'AMOLED स्क्रीन के लिए वास्तविक काली पृष्ठभूमि',
      'units': 'इकाइयां',
      'metric': 'मीट्रिक (किग्रा, किमी)',
      'imperial': 'इंपीरियल (पाउंड, मील)',
      'restTimer': 'आराम टाइमर',
      'notifications': 'सूचनाएं',
      'enabled': 'सक्षम',
      'exportData': 'डेटा निर्यात करें',
      'exportDataSubtitle': 'वर्कआउट को CSV के रूप में निर्यात करें',
      'importData': 'डेटा आयात करें',
      'importDataSubtitle': 'CSV से आयात करें',
      'clearAllData': 'सभी डेटा साफ़ करें',
      'clearAllDataSubtitle': 'सभी वर्कआउट, दिनचर्या, XP और सेटिंग्स हटाएं',
      'aboutRepp': 'रेप के बारे में',
      'privacyPolicy': 'गोपनीयता नीति',
      'terms': 'सेवा की शर्तें',
      'rateApp': 'ऐप रेट करें',
      'cancel': 'रद्द करें',
      'defaultRestTimer': 'डिफ़ॉल्ट आराम टाइमर',
      
      // Stats & Progress
      'allTimeStats': 'कुल आंकड़े',
      'volume': 'वॉल्यूम',
      'sets': 'सेट',
      'reps': 'दोहराव',
      'weight': 'वजन',
      'distance': 'दूरी',
      'currentStreak': 'वर्तमान धारा',
      'longestStreak': 'सबसे लंबी धारा',
      'totalWorkouts': 'कुल वर्कआउट',
      'thisWeek': 'इस सप्ताह',
      'thisMonth': 'इस महीने',
      
      // Quests
      'daily': 'दैनिक',
      'weekly': 'साप्ताहिक',
      'boss': 'बॉस',
      'dailyReset': 'दैनिक रीसेट',
      'weeklyReset': 'साप्ताहिक रीसेट',
      'questsTitle': 'मिशन',
      'questsSubtitle': 'मिशन पूरा करें और XP और स्तर अर्जित करें',
      'questCompleted': 'मिशन पूरा हुआ',
      'claimReward': 'पुरस्कार का दावा करें',
      'claimed': 'दावा किया गया',
      'progress': 'प्रगति',
      'xpReward': 'XP पुरस्कार',
      'reward': 'पुरस्कार',
      
      // XP System
      'xpTitle': 'अनुभव बिंदु',
      'xpLevel': 'स्तर',
      'currentXp': 'वर्तमान XP',
      'nextLevel': 'अगला स्तर',
      'totalXp': 'कुल XP',
      'xpGained': 'XP अर्जित किया',
      'xpPerWorkout': 'प्रति वर्कआउट XP',
      'bonus': 'बोनस',
      'bonusXp': 'बोनस XP',
      
      // Exercises
      'exercisesTitle': 'व्यायाम',
      'searchExercises': 'व्यायाम खोजें...',
      'filter': 'फ़िल्टर',
      'muscle': 'मांसपेशी',
      'equipment': 'उपकरण',
      'difficulty': 'कठिनाई',
      'howTo': 'कैसे करें',
      'instructions': 'निर्देश',
      'breathingTips': 'श्वास युक्तियां',
      'commonMistakes': 'सामान्य गलतियां',
      'variations': 'भिन्नताएं',
      'exerciseDetail': 'व्यायाम विवरण',
      'primaryMuscles': 'प्राथमिक मांसपेशियां',
      'secondaryMuscles': 'माध्यमिक मांसपेशियां',
      'beginner': 'शुरुआती',
      'intermediate': 'मध्यवर्ती',
      'advanced': 'उन्नत',
      'push': 'धक्का',
      'pull': 'खींचना',
      'legs': 'पैर',
      'core': 'कोर',
      
      // Workouts
      'startWorkout': 'वर्कआउट शुरू करें',
      'endWorkout': 'वर्कआउट समाप्त करें',
      'activeWorkout': 'सक्रिय वर्कआउट',
      'workoutHistory': 'वर्कआउट इतिहास',
      'workoutDetails': 'वर्कआउट विवरण',
      'workoutComplete': 'वर्कआउट पूरा',
      'congratulations': 'बधाई हो!',
      'workoutTime': 'वर्कआउट समय',
      'totalVolume': 'कुल वॉल्यूम',
      'duration': 'अवधि',
      'exercise': 'व्यायाम',
      'rest': 'आराम',
      'nextSet': 'अगला सेट',
      'skip': 'छोड़ें',
      'finish': 'समाप्त',
      'resumeWorkout': 'वर्कआउट फिर से शुरू करें',
      'deleteWorkout': 'वर्कआउट हटाएं',
      'editWorkout': 'वर्कआउट संपादित करें',
      
      // Routines
      'routines': 'दिनचर्या',
      'createRoutine': 'दिनचर्या बनाएं',
      'editRoutine': 'दिनचर्या संपादित करें',
      'deleteRoutine': 'दिनचर्या हटाएं',
      'routineName': 'दिनचर्या का नाम',
      'selectExercises': 'व्यायाम चुनें',
      'addExercise': 'व्यायाम जोड़ें',
      'removeExercise': 'व्यायाम हटाएं',
      'scheduleRoutine': 'दिनचर्या शेड्यूल करें',
      'monday': 'सोमवार',
      'tuesday': 'मंगलवार',
      'wednesday': 'बुधवार',
      'thursday': 'गुरुवार',
      'friday': 'शुक्रवार',
      'saturday': 'शनिवार',
      'sunday': 'रविवार',
      'selectDays': 'दिन चुनें',
      'noRoutines': 'अभी तक कोई दिनचर्या नहीं',
      'createFirst': 'अपनी पहली दिनचर्या बनाएं',
      
      // Messages
      'comingSoonNotifications': 'सूचना सेटिंग्स जल्द आ रही हैं!',
      'comingSoonExport': 'निर्यात सुविधा जल्द आ रही है!',
      'comingSoonImport': 'आयात सुविधा जल्द आ रही है!',
      'comingSoonPrivacy': 'गोपनीयता नीति जल्द आ रही है!',
      'comingSoonTerms': 'सेवा की शर्तें जल्द आ रही हैं!',
      'clearDataSuccess': 'सभी ऐप डेटा साफ़ किया गया, XP और सेटिंग्स सहित।',
      'clearDataFailed': 'ऐप डेटा साफ़ करने में विफल:',
      'thanksSupport': 'आपके समर्थन के लिए धन्यवाद!',
      'clearDataTitle': 'सभी डेटा साफ़ करें',
      'clearDataBody': 'यह सभी ऐप डेटा को स्थायी रूप से हटा देगा, जिसमें वर्कआउट, दिनचर्या, व्यक्तिगत रिकॉर्ड, XP प्रगति और सहेजी गई सेटिंग्स शामिल हैं। यह कार्रवाई पूर्ववत नहीं की जा सकती।',
      'clearAll': 'सब कुछ साफ़ करें',
      'noData': 'कोई डेटा उपलब्ध नहीं',
      'loadingExercises': 'व्यायाम लोड हो रहे हैं...',
      'error': 'त्रुटि',
      'errorLoading': 'डेटा लोड करने में त्रुटि',
      'retry': 'पुनः प्रयास करें',
      'save': 'सहेजें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'add': 'जोड़ें',
      'close': 'बंद करें',
      'confirm': 'पुष्टि करें',
      'no': 'नहीं',
      'yes': 'हां',
      'ok': 'ठीक है',
    },
    'gu': {
      // Gujarati translations
      'appTitle': 'રેપ',
      'home': 'હોમ',
      'workouts': 'વર્કઆઉટ્સ',
      'exercises': 'વ્યાયામો',
      'quests': 'કવેસ્ટ્સ',
      'history': 'ઇતિહાસ',
      'profile': 'પ્રોફાઇલ',
      'appearance': 'દેખાવ',
      'settings': 'સેટિંગ્સ',
      'data': 'ડેટા',
      'about': 'વિશે',
      'language': 'ભાષા',
      'selectLanguage': 'ભાષા પસંદ કરો',
      'theme': 'થીમ',
      'system': 'સિસ્ટમ',
      'light': 'હળવો',
      'dark': 'અંધકાર',
      'oledDarkMode': 'OLED ડાર્ક મોડ',
      'oledSubtitle': 'AMOLED સ્ક્રીન માટે સાચો કાળો પૃષ્ઠભૂમિ',
      'units': 'એકમો',
      'metric': 'મેટ્રિક (કિ.ગ્રા., કિ.મી.)',
      'imperial': 'ઇમ્પેરિયલ (પાઉંડ, માઇલ)',
      'restTimer': 'આરામ ટાઇમર',
      'notifications': 'સૂચનાઓ',
      'enabled': 'સક્ષમ',
      'exportData': 'ડેટા નિકાસ કરો',
      'exportDataSubtitle': 'વર્કઆઉટ્સને CSV તરીકે નિકાસ કરો',
      'importData': 'ડેટા આયાત કરો',
      'importDataSubtitle': 'CSV થી આયાત કરો',
      'clearAllData': 'તમામ ડેટા સાફ કરો',
      'clearAllDataSubtitle': 'તમામ વર્કઆઉટ્સ, દિનચર્યા, XP અને સેટિંગ્સ હટાવો',
      'aboutRepp': 'રેપ વિશે',
      'privacyPolicy': 'ગોપનીયતા નીતિ',
      'terms': 'સેવાની શરતો',
      'rateApp': 'ઍપ રેટ કરો',
      'cancel': 'રદ્દ કરો',
      'defaultRestTimer': 'ડિફોલ્ટ આરામ ટાઇમર',
      'allTimeStats': 'કુલ આંકડાઓ',
      'volume': 'વોલ્યુમ',
      'sets': 'સેટ્સ',
      'reps': 'રિપીટ્સ',
      'weight': 'વજન',
      'distance': 'અંતર',
      'currentStreak': 'વર્તમાન સ્ટ્રીક',
      'longestStreak': 'સૌથી લાંબી સ્ટ્રીક',
      'totalWorkouts': 'કુલ વર્કઆઉટ્સ',
      'thisWeek': 'આ સપ્તાહ',
      'thisMonth': 'આ મહિનો',
      'daily': 'દૈનિક',
      'weekly': 'સાપ્તાહિક',
      'boss': 'બૉસ',
      'dailyReset': 'દૈનિક રીસેટ',
      'weeklyReset': 'સાપ્તાહિક રીસેટ',
      'questsTitle': 'કવેસ્ટ્સ',
      'questsSubtitle': 'કવેસ્ટ્સ પૂર્ણ કરો અને XP અને સ્તર અર્જન કરો',
      'questCompleted': 'કવેસ્ટ પૂર્ણ',
      'claimReward': 'પુરસ્કાર દાવો કરો',
      'claimed': 'દાવો કર્યો',
      'progress': 'પ્રગતિ',
      'xpReward': 'XP પુરસ્કાર',
      'reward': 'પુરસ્કાર',
      'xpTitle': 'અનુભવ પોઈન્ટ્સ',
      'xpLevel': 'સ્તર',
      'currentXp': 'વર્તમાન XP',
      'nextLevel': 'આગલો સ્તર',
      'totalXp': 'કુલ XP',
      'xpGained': 'XP પ્રાપ્ત',
      'xpPerWorkout': 'પ્રતિ વર્કઆઉટ XP',
      'bonus': 'બોનસ',
      'bonusXp': 'બોનસ XP',
      'exercisesTitle': 'વ્યાયામો',
      'searchExercises': 'વ્યાયામો શોધો...',
      'filter': 'ફિલ્ટર',
      'muscle': 'સ્નાયુ',
      'equipment': 'સાધન',
      'difficulty': 'મુશ્કેલી',
      'howTo': 'કેવું કરવું',
      'instructions': 'સૂચનાઓ',
      'breathingTips': 'શ્વાસ સુझાવો',
      'commonMistakes': 'સામાન્ય ભૂલો',
      'variations': 'ભિન્નતાઓ',
      'exerciseDetail': 'વ્યાયાम વિગતો',
      'primaryMuscles': 'પ્રાથમિક સ્નાયુઓ',
      'secondaryMuscles': 'ગૌણ સ્નાયુઓ',
      'beginner': 'શરૂઆતીનું',
      'intermediate': 'મધ્યમ',
      'advanced': 'અદ્યતન',
      'push': 'ધક્કો',
      'pull': 'ખેંચો',
      'legs': 'પગ',
      'core': 'મૂલ',
      'startWorkout': 'વર્કઆઉટ શરૂ કરો',
      'endWorkout': 'વર્કઆઉટ સમાપ્ત કરો',
      'activeWorkout': 'સક્રિય વર્કઆઉટ',
      'workoutHistory': 'વર્કઆઉટ ઇતિહાસ',
      'workoutDetails': 'વર્કઆઉટ વિગતો',
      'workoutComplete': 'વર્કઆઉટ સંપૂર્ણ',
      'congratulations': 'બધાઇ હો!',
      'workoutTime': 'વર્કઆઉટ સમય',
      'totalVolume': 'કુલ વોલ્યુમ',
      'duration': 'અવધિ',
      'exercise': 'વ્યાયામ',
      'rest': 'આરામ',
      'nextSet': 'આગલો સેટ',
      'skip': 'અવગણો',
      'finish': 'સમાપ્ત',
      'resumeWorkout': 'વર્કઆઉટ ફરી શરૂ કરો',
      'deleteWorkout': 'વર્કઆઉટ હટાવો',
      'editWorkout': 'વર્કઆઉટ સંપાદિત કરો',
      'routines': 'દિનચર્યા',
      'createRoutine': 'દિનચર્યા બનાવો',
      'editRoutine': 'દિનચર્યા સંપાદિત કરો',
      'deleteRoutine': 'દિનચર્યા હટાવો',
      'routineName': 'દિનચર્યા નામ',
      'selectExercises': 'વ્યાયામો પસંદ કરો',
      'addExercise': 'વ્યાયામ ઉમેરો',
      'removeExercise': 'વ્યાયામ હટાવો',
      'scheduleRoutine': 'દિનચર્યા શેડ્યુલ કરો',
      'monday': 'સોમવાર',
      'tuesday': 'મંગળવાર',
      'wednesday': 'બુધવાર',
      'thursday': 'ગુરુવાર',
      'friday': 'શુક્રવાર',
      'saturday': 'શનિવાર',
      'sunday': 'રવિવાર',
      'selectDays': 'દિવસો પસંદ કરો',
      'noRoutines': 'હજી કોઈ દિનચર્યા નથી',
      'createFirst': 'તમારી પહેલી દિનચર્યા બનાવો',
      'comingSoonNotifications': 'સૂચના સેટિંગ્સ જલ્દીથી આવી રહી છે!',
      'comingSoonExport': 'નિકાસ સુવિધા જલ્દીથી આવી રહી છે!',
      'comingSoonImport': 'આયાત સુવિધા જલ્દીથી આવી રહી છે!',
      'comingSoonPrivacy': 'ગોપનીયતા નીતિ જલ્દીથી આવી રહી છે!',
      'comingSoonTerms': 'સેવાની શરતો જલ્દીથી આવી રહી છે!',
      'clearDataSuccess': 'તમામ ઍપ ડેટા સાફ કર્યો, XP અને સેટિંગ્સ સહિત।',
      'clearDataFailed': 'ઍપ ડેટા સાફ કરવાში નિષ્ફળ:',
      'thanksSupport': 'તમારા સમર્થન માટે આભાર!',
      'clearDataTitle': 'તમામ ડેટા સાફ કરો',
      'clearDataBody': 'આ તમામ ઍપ ડેટા કાયમી રીતે હટાવશે, જેમાં વર્કઆઉટ્સ, દિનચર્યા, ખ્યાતિમાન રેકોર્ડ્સ, XP પ્રગતિ અને સંગ્રહિત સેટિંગ્સ છે। આ ક્રિયા રદ કરી શકાતી નથી.',
      'clearAll': 'બધું સાફ કરો',
      'noData': 'કોઈ ડેટા ઉપલબ્ધ નથી',
      'loadingExercises': 'વ્યાયામો લોડ કરી રહ્યા છે...',
      'error': 'ભૂલ',
      'errorLoading': 'ડેટા લોડ કરવામાં ભૂલ',
      'retry': 'ફરી પ્રયાસ કરો',
      'save': 'સંગ્રહ કરો',
      'delete': 'હટાવો',
      'edit': 'સંપાદિત કરો',
      'add': 'ઉમેરો',
      'close': 'બંધ કરો',
      'confirm': 'પુષ્ટિ કરો',
      'no': 'નહીં',
      'yes': 'હા',
      'ok': 'ઓકે',
    },
    'bn': {
      'profile': 'প্রোফাইল',
      'appearance': 'চেহারা',
      'settings': 'সেটিংস',
      'data': 'ডেটা',
      'about': 'সম্পর্কে',
      'language': 'ভাষা',
      'selectLanguage': 'ভাষা নির্বাচন করুন',
      'cancel': 'বাতিল',
    },
    'ta': {
      'profile': 'சுயவிவரம்',
      'appearance': 'தோற்றம்',
      'settings': 'அமைப்புகள்',
      'data': 'தரவு',
      'about': 'பற்றி',
      'language': 'மொழி',
      'selectLanguage': 'மொழியை தேர்ந்தெடுக்கவும்',
      'cancel': 'ரத்து',
    },
    'te': {
      'profile': 'ప్రొఫైల్',
      'appearance': 'రూపం',
      'settings': 'సెట్టింగ్స్',
      'data': 'డేటా',
      'about': 'గురించి',
      'language': 'భాష',
      'selectLanguage': 'భాష ఎంచుకోండి',
      'cancel': 'రద్దు',
    },
    'ur': {
      'profile': 'پروفائل',
      'appearance': 'ظاہری شکل',
      'settings': 'ترتیبات',
      'data': 'ڈیٹا',
      'about': 'متعلق',
      'language': 'زبان',
      'selectLanguage': 'زبان منتخب کریں',
      'cancel': 'منسوخ کریں',
    },
  };

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return localizations ?? AppLocalizations(const Locale(_fallbackCode));
  }

  static const Map<String, String> _fallbackLanguages = {};

  String _code() {
    var code = locale.languageCode;
    
    // If it's an unsupported regional language, map it to a supported parent language
    if (_fallbackLanguages.containsKey(code)) {
      code = _fallbackLanguages[code]!;
    }
    
    if (_localizedValues.containsKey(code)) return code;
    return _fallbackCode;
  }

  String _value(String key) {
    final code = _code();
    return _localizedValues[code]?[key] ?? _localizedValues[_fallbackCode]![key] ?? key;
  }

  String get appTitle => _value('appTitle');
  String get home => _value('home');
  String get workouts => _value('workouts');
  String get exercises => _value('exercises');
  String get quests => _value('quests');
  String get history => _value('history');
  String get profile => _value('profile');
  String get appearance => _value('appearance');
  String get settings => _value('settings');
  String get data => _value('data');
  String get about => _value('about');
  String get language => _value('language');
  String get selectLanguage => _value('selectLanguage');
  String get theme => _value('theme');
  String get system => _value('system');
  String get light => _value('light');
  String get dark => _value('dark');
  String get oledDarkMode => _value('oledDarkMode');
  String get oledSubtitle => _value('oledSubtitle');
  String get units => _value('units');
  String get metric => _value('metric');
  String get imperial => _value('imperial');
  String get restTimer => _value('restTimer');
  String get notifications => _value('notifications');
  String get enabled => _value('enabled');
  String get exportData => _value('exportData');
  String get exportDataSubtitle => _value('exportDataSubtitle');
  String get importData => _value('importData');
  String get importDataSubtitle => _value('importDataSubtitle');
  String get clearAllData => _value('clearAllData');
  String get clearAllDataSubtitle => _value('clearAllDataSubtitle');
  String get aboutRepp => _value('aboutRepp');
  String get privacyPolicy => _value('privacyPolicy');
  String get terms => _value('terms');
  String get rateApp => _value('rateApp');
  String get cancel => _value('cancel');
  String get defaultRestTimer => _value('defaultRestTimer');
  String get allTimeStats => _value('allTimeStats');
  String get volume => _value('volume');
  String get sets => _value('sets');
  String get reps => _value('reps');
  String get weight => _value('weight');
  String get distance => _value('distance');
  String get currentStreak => _value('currentStreak');
  String get longestStreak => _value('longestStreak');
  String get totalWorkouts => _value('totalWorkouts');
  String get thisWeek => _value('thisWeek');
  String get thisMonth => _value('thisMonth');
  String get daily => _value('daily');
  String get weekly => _value('weekly');
  String get boss => _value('boss');
  String get dailyReset => _value('dailyReset');
  String get weeklyReset => _value('weeklyReset');
  String get questsTitle => _value('questsTitle');
  String get questsSubtitle => _value('questsSubtitle');
  String get questCompleted => _value('questCompleted');
  String get claimReward => _value('claimReward');
  String get claimed => _value('claimed');
  String get progress => _value('progress');
  String get xpReward => _value('xpReward');
  String get reward => _value('reward');
  String get xpTitle => _value('xpTitle');
  String get xpLevel => _value('xpLevel');
  String get currentXp => _value('currentXp');
  String get nextLevel => _value('nextLevel');
  String get totalXp => _value('totalXp');
  String get xpGained => _value('xpGained');
  String get xpPerWorkout => _value('xpPerWorkout');
  String get bonus => _value('bonus');
  String get bonusXp => _value('bonusXp');
  String get exercisesTitle => _value('exercisesTitle');
  String get searchExercises => _value('searchExercises');
  String get filter => _value('filter');
  String get muscle => _value('muscle');
  String get equipment => _value('equipment');
  String get difficulty => _value('difficulty');
  String get howTo => _value('howTo');
  String get instructions => _value('instructions');
  String get breathingTips => _value('breathingTips');
  String get commonMistakes => _value('commonMistakes');
  String get variations => _value('variations');
  String get exerciseDetail => _value('exerciseDetail');
  String get primaryMuscles => _value('primaryMuscles');
  String get secondaryMuscles => _value('secondaryMuscles');
  String get beginner => _value('beginner');
  String get intermediate => _value('intermediate');
  String get advanced => _value('advanced');
  String get push => _value('push');
  String get pull => _value('pull');
  String get legs => _value('legs');
  String get core => _value('core');
  String get startWorkout => _value('startWorkout');
  String get endWorkout => _value('endWorkout');
  String get activeWorkout => _value('activeWorkout');
  String get workoutHistory => _value('workoutHistory');
  String get workoutDetails => _value('workoutDetails');
  String get workoutComplete => _value('workoutComplete');
  String get congratulations => _value('congratulations');
  String get workoutTime => _value('workoutTime');
  String get totalVolume => _value('totalVolume');
  String get duration => _value('duration');
  String get exercise => _value('exercise');
  String get rest => _value('rest');
  String get nextSet => _value('nextSet');
  String get skip => _value('skip');
  String get finish => _value('finish');
  String get resumeWorkout => _value('resumeWorkout');
  String get deleteWorkout => _value('deleteWorkout');
  String get editWorkout => _value('editWorkout');
  String get routines => _value('routines');
  String get createRoutine => _value('createRoutine');
  String get editRoutine => _value('editRoutine');
  String get deleteRoutine => _value('deleteRoutine');
  String get routineName => _value('routineName');
  String get selectExercises => _value('selectExercises');
  String get addExercise => _value('addExercise');
  String get removeExercise => _value('removeExercise');
  String get scheduleRoutine => _value('scheduleRoutine');
  String get monday => _value('monday');
  String get tuesday => _value('tuesday');
  String get wednesday => _value('wednesday');
  String get thursday => _value('thursday');
  String get friday => _value('friday');
  String get saturday => _value('saturday');
  String get sunday => _value('sunday');
  String get selectDays => _value('selectDays');
  String get noRoutines => _value('noRoutines');
  String get createFirst => _value('createFirst');
  String get comingSoonNotifications => _value('comingSoonNotifications');
  String get comingSoonExport => _value('comingSoonExport');
  String get comingSoonImport => _value('comingSoonImport');
  String get comingSoonPrivacy => _value('comingSoonPrivacy');
  String get comingSoonTerms => _value('comingSoonTerms');
  String get clearDataSuccess => _value('clearDataSuccess');
  String get clearDataFailed => _value('clearDataFailed');
  String get thanksSupport => _value('thanksSupport');
  String get clearDataTitle => _value('clearDataTitle');
  String get clearDataBody => _value('clearDataBody');
  String get clearAll => _value('clearAll');
  String get noData => _value('noData');
  String get loadingExercises => _value('loadingExercises');
  String get error => _value('error');
  String get errorLoading => _value('errorLoading');
  String get retry => _value('retry');
  String get save => _value('save');
  String get delete => _value('delete');
  String get edit => _value('edit');
  String get add => _value('add');
  String get close => _value('close');
  String get confirm => _value('confirm');
  String get no => _value('no');
  String get yes => _value('yes');
  String get ok => _value('ok');

  String languageName(String code) => _value('language_$code');

  static const Map<String, String> nativeLanguageNames = {
    'en': 'English',
    'ta': 'தமிழ்',
  };

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}


