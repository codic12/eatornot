// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui'; // Required for ImageFilter.blur

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import 'package:percent_indicator/percent_indicator.dart';

// --- IMPORTS ---
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ionicons/ionicons.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:cupertino_icons/cupertino_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

// --- IMPORTANT SECURITY WARNING ---
// REMOVED API KEY - Replace with your secure method
const String _geminiApiKey =
    "AIzaSyCdq_4S8X__8VlJD1uo1YP6GlkecrSj-Sw"; // <-- Replace this

// --- NEW COLOR CONSTANTS FOR CONSISTENT SCHEME ---
const Color _primaryBlue = Color(0xFF63A1F4); // Pastel Blue (New Primary)
const Color _accentRed = Color(0xFFEF4444); // Error/Accent Red (Unhealthy)
const Color _successGreen = Color(
  0xFF10B981,
); // Original Green (Good Food Only)
const Color _warningOrange = Color(0xFFF59E0B); // Warning Orange
const Color _cardBackground = Color.fromARGB(
  255,
  230,
  231,
  232,
); // Light Grayish Background for Cards

// --- MODIFIED: Database Helper Class ---
class DatabaseHelper {
  static const _databaseName = "FoodHistory.db";
  // --- NEW: Incremented version for migration ---
  static const _databaseVersion = 2;

  static const table = 'history';

  static const columnId = 'id';
  static const columnFoodName = 'foodName';
  static const columnHealthScore = 'healthScore';
  // --- NEW: Column for goal-specific score ---
  static const columnGoalAlignmentScore = 'goalAlignmentScore';
  static const columnCalories = 'calories';
  static const columnImagePath = 'imagePath';
  static const columnFullResponse = 'fullResponse';
  static const columnCreatedAt = 'createdAt';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = p.join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      // --- NEW: Handle database upgrades ---
      onUpgrade: _onUpgrade,
    );
  }
Future _onCreate(Database db, int version) async {
  // Store the SQL in a variable for clarity
  const String createTableSQL = '''
    CREATE TABLE $table (
      $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
      $columnFoodName TEXT NOT NULL,
      $columnHealthScore INTEGER,
      $columnGoalAlignmentScore INTEGER,
      $columnCalories INTEGER,
      $columnImagePath TEXT NOT NULL,
      $columnFullResponse TEXT NOT NULL,
      $columnCreatedAt TEXT NOT NULL
    )
  ''';
  
  // FIX: Use .trim() to remove the leading whitespace and newline
  await db.execute(createTableSQL.trim());
}
  // --- NEW: Migration logic ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN $columnGoalAlignmentScore INTEGER DEFAULT 5',
      );
    }
  }

  Future<int> insert(HistoryItem item) async {
    Database db = await instance.database;
    return await db.insert(table, item.toMap());
  }

  Future<List<HistoryItem>> queryAllRows() async {
    Database db = await instance.database;
    final maps = await db.query(table, orderBy: '$columnCreatedAt DESC');
    return List.generate(maps.length, (i) {
      return HistoryItem.fromMap(maps[i]);
    });
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }
}

// --- MODIFIED: History Data Model ---
class HistoryItem {
  final int? id;
  final String foodName;
  final int healthScore;
  // --- NEW: Field for goal-specific score ---
  final int goalAlignmentScore;
  final int calories;
  final String imagePath;
  final String fullResponse;
  final DateTime createdAt;

  HistoryItem({
    this.id,
    required this.foodName,
    required this.healthScore,
    required this.goalAlignmentScore,
    required this.calories,
    required this.imagePath,
    required this.fullResponse,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      DatabaseHelper.columnId: id,
      DatabaseHelper.columnFoodName: foodName,
      DatabaseHelper.columnHealthScore: healthScore,
      DatabaseHelper.columnGoalAlignmentScore: goalAlignmentScore, // NEW
      DatabaseHelper.columnCalories: calories,
      DatabaseHelper.columnImagePath: imagePath,
      DatabaseHelper.columnFullResponse: fullResponse,
      DatabaseHelper.columnCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map[DatabaseHelper.columnId],
      foodName: map[DatabaseHelper.columnFoodName],
      healthScore: map[DatabaseHelper.columnHealthScore],
      // --- NEW: Read from map, provide default for old entries ---
      goalAlignmentScore: map[DatabaseHelper.columnGoalAlignmentScore] ?? 5,
      calories: map[DatabaseHelper.columnCalories],
      imagePath: map[DatabaseHelper.columnImagePath],
      fullResponse: map[DatabaseHelper.columnFullResponse],
      createdAt: DateTime.parse(map[DatabaseHelper.columnCreatedAt]),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_geminiApiKey.isEmpty) {
    print("ERROR: Gemini API Key is not set.");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = _primaryBlue; // Pastel Blue
    const Color accentColor = _accentRed; // Red for accents/error

    TextTheme createTextTheme(ThemeData baseTheme) {
      final baseTextTheme = GoogleFonts.figtreeTextTheme(baseTheme.textTheme);
      return baseTextTheme.copyWith(
        displayLarge: GoogleFonts.lexendDeca(
          textStyle: baseTextTheme.displayLarge,
        ),
        displayMedium: GoogleFonts.lexendDeca(
          textStyle: baseTextTheme.displayMedium,
        ),
        displaySmall: GoogleFonts.lexendDeca(
          textStyle: baseTextTheme.displaySmall,
        ),
        headlineLarge: GoogleFonts.lexendDeca(
          textStyle: baseTextTheme.headlineLarge,
        ),
        headlineMedium: GoogleFonts.lexendDeca(
          textStyle: baseTextTheme.headlineMedium,
        ),
        headlineSmall: GoogleFonts.lexendDeca(
          textStyle: baseTextTheme.headlineSmall,
        ),
      );
    }

    // Light Theme: light but a little grayer side
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        brightness: Brightness.light,
        // Using a slightly grayish background for modern look
        background: const Color(0xFFF8F8FA),
        surface: const Color.fromARGB(255, 241, 241, 241),
      ),
      useMaterial3: true,
      textTheme: createTextTheme(ThemeData.light()).apply(
        bodyColor: const Color(0xFF1F2937),
        displayColor: const Color(0xFF111827),
      ),
    );

    // Dark Theme: Maintaining dark mode consistency
    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        brightness: Brightness.dark,
        background: const Color(0xFF111827),
        surface: const Color(0xFF1F2937),
      ),
      useMaterial3: true,
      textTheme: createTextTheme(
        ThemeData.dark(),
      ).apply(bodyColor: const Color(0xFFD1D5DB), displayColor: Colors.white),
    );

    return MaterialApp(
      title: 'Eat or Not',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const InitialLoadingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class InitialLoadingScreen extends StatefulWidget {
  const InitialLoadingScreen({super.key});

  @override
  State<InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<InitialLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _loadAndRedirect();
  }

  Future<void> _loadAndRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userGoal = prefs.getString('user_goal');
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (userGoal != null && userGoal.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const IntroScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// --- MODIFIED: IntroScreen now collects user's name ---
class IntroScreen extends StatefulWidget {
  final bool isUpdating;
  const IntroScreen({super.key, this.isUpdating = false});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _nameController = TextEditingController(); // NEW
  final _goalController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('user_name') ?? '';
    _goalController.text = prefs.getString('user_goal') ?? '';
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameController.text.trim());
      await prefs.setString('user_goal', _goalController.text.trim());

      if (!mounted) return;

      if (widget.isUpdating) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: _successGreen, // Using green for success message
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppShell()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Ionicons.leaf_outline,
                    size: 100,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome!',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Let\'s get to know you and your goals.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    // NEW NAME FIELD
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'What should we call you?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    textAlign: TextAlign.center,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _goalController,
                    decoration: const InputDecoration(
                      labelText:
                          'e.g., "Lose weight", "Build muscle", "Eat less sugar"',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      alignLabelWithHint: true,
                    ),
                    textAlign: TextAlign.center,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a goal';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveData(),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: Icon(
                      widget.isUpdating
                          ? Ionicons.save_outline
                          : Ionicons.arrow_forward,
                    ),
                    label: Text(widget.isUpdating ? 'Save' : 'Continue'),
                    onPressed: _saveData,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// --- END MODIFIED INTRO SCREEN ---

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}
// lib/main.dart

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // --- MODIFICATION: Make _pages a 'late final' ---
  late final List<Widget> _pages;
  // --- END MODIFICATION ---

  // --- NEW: Add initState to initialize _pages ---
  @override
  void initState() {
    super.initState();
    _pages = [
      AnalyzePage(onShowHistory: () => _onItemTapped(1)), // Pass the callback
      const HistoryPage(),
      const SettingsPage(),
    ];
  }
  // --- END NEW ---

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages, // This now uses the initialized list
      ),
      bottomNavigationBar: Theme(
        // ... rest of AppShell is unchanged ...
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Theme.of(
            context,
          ).colorScheme.primary, // Use new primary color
          unselectedItemColor: Colors.grey.shade600,
          showUnselectedLabels: false,
          showSelectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor:
              Colors.grey[300], // Use light grayish color for navbar background
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.camera),
              activeIcon: Icon(CupertinoIcons.camera_fill),
              label: 'Analyze',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.time),
              activeIcon: Icon(CupertinoIcons.time_solid),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.settings),
              activeIcon: Icon(CupertinoIcons.settings_solid),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyzePage extends StatefulWidget {
  // --- NEW: Callback to show the history tab ---
  final VoidCallback onShowHistory;
  const AnalyzePage({super.key, required this.onShowHistory});
  // --- END NEW ---

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  // --- UI State ---
  Map<String, dynamic>? _nutritionResult;
  bool _isLoading = false;
  String _errorMessage = '';
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // --- NEW: Dashboard State ---
  String _userName = '';
  List<HistoryItem> _historyItems = [];
  bool _isDashboardLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isDashboardLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final history = await DatabaseHelper.instance.queryAllRows();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Gurjus';
        _historyItems = history;
        _isDashboardLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _nutritionResult = null;
          _errorMessage = '';
          _isLoading = true;
        });
        await _analyzeFood(_imageFile!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _analyzeFood(File imageFile) async {
    if (_geminiApiKey.isEmpty) {
      setState(() {
        _errorMessage = "AI Service not configured.";
        _isLoading = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String userGoal =
        prefs.getString('user_goal') ?? 'General health improvement';

    final String geminiModel = "gemini-2.5-flash";
    final String geminiBaseUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';
    final Uri geminiUrl = Uri.parse('$geminiBaseUrl?key=$_geminiApiKey');

    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // --- PROMPT MODIFIED to ask for goalAlignmentScore ---
      final prompt =
          """
Analyze the food in this image. My health goal is: "$userGoal".

Respond ONLY with a valid JSON object (no markdown formatting).
Keep descriptions and feedback concise and easy to read.

{
  "foodName": "string",
  "servingSize": "string (e.g., '1 cup')",
  "calories": number,
  "macros": { "protein": number, "carbs": number, "fat": number, "fiber": number },
  "vitamins": ["string"],
  "minerals": ["string"],
  "healthScore": number (1-10 scale, general healthiness),
  "goalAlignmentScore": number (1-10 scale, specifically how well this food aligns with my goal: '$userGoal'),
  "tags": ["string"],
  "benefits": "string (1-2 short sentences)",
  "notes": "string (1-2 short sentences, if any)",
  "healthierAlternatives": [ { "name": "string", "reason": "string (very brief)", "emoji": "string" } ],
  "goalFeedback": "string (Friendly, 1-2 sentence feedback on how this food impacts my goal. Be encouraging but honest.)"
}

If the food is unhealthy, be direct. Provide 2 healthier alternatives.
""";

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
        "generationConfig": {"responseMimeType": "application/json"},
      };

      final response = await http
          .post(
            geminiUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        final rawText =
            decodedResponse['candidates']
                    ?.first?['content']?['parts']
                    ?.first?['text']
                as String?;

        if (rawText != null) {
          try {
            final nutritionData = jsonDecode(rawText) as Map<String, dynamic>;
            if (nutritionData['foodName'] == null) {
              throw const FormatException('Missing fields in AI response.');
            }
            await _saveToHistory(nutritionData, imageFile);
            setState(() {
              _nutritionResult = nutritionData;
              _errorMessage = '';
              _isLoading = false;
            });
            await _loadDashboardData(); // Refresh dashboard data
          } catch (e) {
            setState(() {
              print(e);
              _errorMessage = 'AI returned an invalid format.';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = 'AI returned an unexpected response.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'AI Service Error (${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().contains('TimeoutException')
            ? 'Request timed out. Try again.'
            : 'Error analyzing image: $e';
        _isLoading = false;
      });
    }
  }

  // --- MODIFIED: Save new goal score to Database ---
  Future<void> _saveToHistory(
    Map<String, dynamic> result,
    File imageFile,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(imageFile.path);
      final savedImagePath = p.join(appDir.path, fileName);
      final File savedImage = await imageFile.copy(savedImagePath);

      final item = HistoryItem(
        foodName: result['foodName'] as String? ?? 'Unknown Food',
        healthScore: (result['healthScore'] as num?)?.toInt() ?? 5,
        // --- NEW ---
        goalAlignmentScore:
            (result['goalAlignmentScore'] as num?)?.toInt() ?? 5,
        calories: (result['calories'] as num?)?.toInt() ?? 0,
        imagePath: savedImage.path,
        fullResponse: jsonEncode(result),
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.instance.insert(item);
    } catch (e) {
      debugPrint("Failed to save history: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save to history.'),
            backgroundColor: _accentRed, // Use red for error
          ),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _nutritionResult = null;
      _isLoading = false;
      _errorMessage = '';
      _imageFile = null;
    });
    // Refresh dashboard data when returning to it
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(duration: 300.ms, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage.isNotEmpty) return _buildErrorState();
    if (_nutritionResult != null) return _buildResultsState();
    // --- The "Initial State" is now the dashboard ---
    return _buildDashboardState();
  }

  // --- NEW: Dashboard UI ---
  Widget _buildDashboardState() {
    final theme = Theme.of(context);
    final streak = _calculateStreak(_historyItems);
    final avgScore = _calculateAverageScore(_historyItems);

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        key: const ValueKey('dashboard'),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        children: <Widget>[
          Text(
            'Welcome back,',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Gurjus' + '.',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                theme,
                icon: Ionicons.camera_outline,
                label: 'Camera',
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                theme,
                icon: Ionicons.images_outline,
                label: 'Gallery',
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _RecentHistoryCard(
            items: _historyItems,
            onShowMore: widget.onShowHistory,
            onRefresh:
                _loadDashboardData, // Pass refresh for when popping detail page
          ),
          const SizedBox(height: 20),

          // --- NEW: Stat Cards ---
          Row(
            children: [
              Expanded(child: _StreakCard(streak: streak)),
              const SizedBox(width: 16),
              Expanded(child: _AverageScoreCard(averageScore: avgScore)),
            ],
          ),
          const SizedBox(height: 16),

          // --- NEW: Progress Chart ---
          if (_historyItems.isNotEmpty)
            _ProgressChartCard(historyItems: _historyItems),

          // --- NEW: Recent History Card ---
          const SizedBox(height: 16),

          // --- END NEW ---

          // --- Action Buttons ---
        ].animate(interval: 80.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
      ),
    );
  }

  // --- NEW: Helper to calculate streak ---
  int _calculateStreak(List<HistoryItem> items) {
    if (items.isEmpty) return 0;

    // Get unique dates, ignoring time
    final uniqueDates = items
        .map(
          (item) => DateTime(
            item.createdAt.year,
            item.createdAt.month,
            item.createdAt.day,
          ),
        )
        .toSet()
        .toList();

    uniqueDates.sort((a, b) => b.compareTo(a)); // Sort descending

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    // Check if the most recent entry is today or yesterday
    if (uniqueDates.first.isBefore(
      todayDateOnly.subtract(const Duration(days: 1)),
    )) {
      return 0;
    }

    int streak = 0;
    if (uniqueDates.first == todayDateOnly ||
        uniqueDates.first == todayDateOnly.subtract(const Duration(days: 1))) {
      streak = 1;
      for (int i = 0; i < uniqueDates.length - 1; i++) {
        final currentDay = uniqueDates[i];
        final nextDay = uniqueDates[i + 1];
        if (currentDay.difference(nextDay).inDays == 1) {
          streak++;
        } else {
          break; // Streak is broken
        }
      }
    }

    return streak;
  }

  // --- NEW: Helper to calculate average score ---
  double _calculateAverageScore(List<HistoryItem> items) {
    if (items.isEmpty) return 0.0;
    final totalScore = items.fold(
      0,
      (sum, item) => sum + item.goalAlignmentScore,
    );
    return totalScore / items.length;
  }

  Widget _buildActionButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: theme.textTheme.labelLarge,
        backgroundColor: theme.colorScheme.primary, // Use new primary color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                _imageFile!,
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 40),
          Lottie.asset(
            'assets/anim/loading.json',
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  color: theme.colorScheme.primary,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your food...',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Ionicons.alert_circle_outline,
                size: 60,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops!',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Ionicons.refresh),
              label: const Text('Try Again'),
              onPressed: _reset,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildResultsState() {
    return ResultsDisplayWidget(
      key: const ValueKey('results'),
      nutritionResult: _nutritionResult!,
      imageFile: _imageFile!,
      onReset: _reset,
    );
  }
}

// --- NEW WIDGETS FOR DASHBOARD CARDS ---

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _cardBackground, // Use new card background color
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Ionicons.flame,
                  color: _warningOrange,
                ), // Use orange for flame
                const SizedBox(width: 8),
                Text(
                  'Streak',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$streak',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary, // Use new primary blue
                    ),
                  ),
                  TextSpan(
                    text: ' days',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AverageScoreCard extends StatelessWidget {
  final double averageScore;
  const _AverageScoreCard({required this.averageScore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _cardBackground, // Use new card background color
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Ionicons.golf,
                  color: theme.colorScheme.primary,
                ), // Use new primary blue
                const SizedBox(width: 8),
                Text(
                  'Avg Score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: averageScore.toStringAsFixed(1),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _successGreen, // Keep green for positive avg score
                    ),
                  ),
                  TextSpan(
                    text: '/10',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/main.dart

// ... after _ProgressChartCard class ...

// --- NEW WIDGET FOR DASHBOARD RECENT HISTORY ---
class _RecentHistoryCard extends StatelessWidget {
  final List<HistoryItem> items;
  final VoidCallback onShowMore;
  final VoidCallback onRefresh; // To refresh data after popping from detail

  const _RecentHistoryCard({
    required this.items,
    required this.onShowMore,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Take the 3 most recent items
    final recentItems = items.take(3).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _cardBackground, // Use new card background color
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recently Analyzed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: onShowMore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        theme.colorScheme.primary, // Use new primary blue
                  ),
                  child: const Row(
                    children: [
                      Text('Show More'),
                      SizedBox(width: 4),
                      Icon(Ionicons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recentItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Ionicons.leaf_outline,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No activity logged yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                // Build a list tile for each of the 3 items
                children: recentItems.map((item) {
                  final file = File(item.imagePath);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: file.existsSync()
                            ? Image.file(
                                file,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey.shade200,
                                child: const Icon(Ionicons.image_outline),
                              ),
                      ),
                      title: Text(
                        item.foodName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${item.calories} kcal • Goal Score: ${item.goalAlignmentScore}/10',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Ionicons.chevron_forward, size: 20),
                      onTap: () {
                        // Navigate to the detail page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistoryDetailPage(item: item),
                          ),
                        ).then((_) {
                          // When popping back, refresh the dashboard data
                          onRefresh();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
// --- END NEW WIDGET ---

// --- Results Display Widget (No major changes, just formatting) ---
// ... rest of file is unchanged ...

class _ProgressChartCard extends StatelessWidget {
  final List<HistoryItem> historyItems;
  const _ProgressChartCard({required this.historyItems});

  // Helper to determine the line color based on a score
  Color _getScoreColor(int score) {
    if (score >= 8) return _successGreen; // Use specific green for good score
    if (score >= 5) return _warningOrange; // Use orange for neutral/warning
    return _accentRed; // Use red for low score
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Take the most recent 7 items for the chart
    final recentItems = historyItems.take(7).toList().reversed.toList();

    final spots = [
      for (var i = 0; i < recentItems.length; i++)
        FlSpot(i.toDouble(), recentItems[i].goalAlignmentScore.toDouble()),
    ];

    // Determine the color of the last point to set the line color
    final Color lineColor = recentItems.isNotEmpty
        ? _getScoreColor(recentItems.last.goalAlignmentScore)
        : theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: _cardBackground, // Use new card background color
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Recent Progress',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor, // Use calculated color
                      barWidth: 5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: lineColor,
                            strokeColor: isDark
                                ? theme.colorScheme.surface
                                : Colors.white,
                            strokeWidth: 3,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            lineColor.withOpacity(0.3),
                            lineColor.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  minX: 0,
                  maxX: (recentItems.length - 1).toDouble(),
                  minY: 0,
                  maxY: 11,
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      // getTooltipColor: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Results Display Widget (No major changes, just formatting) ---
class ResultsDisplayWidget extends StatelessWidget {
  final Map<String, dynamic> nutritionResult;
  final File imageFile;
  final VoidCallback? onReset;

  const ResultsDisplayWidget({
    super.key,
    required this.nutritionResult,
    required this.imageFile,
    this.onReset,
  });

  // MODIFIED to use new constants
  Color _getRatingColor(BuildContext context, int score) {
    if (score >= 8) return _successGreen; // Green for high score
    if (score >= 5) return _warningOrange; // Orange for moderate score
    return _accentRed; // Red for low score
  }

  IconData _getScoreIcon(int score) {
    if (score >= 8) return Ionicons.thumbs_up;
    if (score >= 5) return Ionicons.remove_circle;
    return Ionicons.thumbs_down;
  }

  // MODIFIED to use new constants
  Color _getRatingColorTag(BuildContext context, int score) {
    if (score >= 8) return _successGreen.withOpacity(0.3); // Light green tag
    if (score >= 5) return _warningOrange.withOpacity(0.3); // Light orange tag
    return _accentRed.withOpacity(0.3); // Light red tag
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = nutritionResult;

    final foodName = data['foodName'] as String? ?? 'Unknown Food';
    final servingSize = data['servingSize'] as String? ?? 'N/A';
    final calories = (data['calories'] as num?)?.toInt() ?? 0;
    final macros = (data['macros'] as Map<String, dynamic>? ?? {});
    final healthScore = (data['healthScore'] as num?)?.toInt() ?? 5;
    final benefits = data['benefits'] as String? ?? '';
    final notes = data['notes'] as String? ?? '';
    final tags = (data['tags'] as List?)?.whereType<String>().toList() ?? [];
    final vitamins =
        (data['vitamins'] as List?)?.whereType<String>().toList() ?? [];
    final minerals =
        (data['minerals'] as List?)?.whereType<String>().toList() ?? [];
    final alternatives =
        (data['healthierAlternatives'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final goalFeedback = data['goalFeedback'] as String? ?? '';

    final totalMacros =
        (macros['protein'] as num? ?? 0) +
        (macros['carbs'] as num? ?? 0) +
        (macros['fat'] as num? ?? 0);

    final Color ratingColor = _getRatingColor(context, healthScore);
    final Color tagsColor = _getRatingColorTag(context, healthScore);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.file(
                            imageFile,
                            height: 240,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10.0,
                                sigmaY: 10.0,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ratingColor.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  _getScoreIcon(healthScore),
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          right: 20,
                          child: LiquidGlass(
                            shape: LiquidRoundedSuperellipse(
                              borderRadius: const Radius.circular(200),
                            ),
                            settings: LiquidGlassSettings(
                              blur: 3.5,
                              glassColor: Colors.white.withOpacity(0.2),
                            ),
                            child: HealthScoreIndicator(score: healthScore),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      foodName,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Serving: $servingSize',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags
                            .map(
                              (tag) => Chip(
                                label: Text(tag),
                                backgroundColor: tagsColor,
                                labelStyle: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                                side: BorderSide.none,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildCalorieCard(theme, calories, ratingColor),
                    if (alternatives.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildAlternativesCard(theme, healthScore, alternatives),
                    ],
                    if (goalFeedback.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        theme,
                        title: 'Alignment with Your Goal',
                        icon: Ionicons.golf_outline,
                        iconColor:
                            theme.colorScheme.primary, // Use new primary blue
                        content: goalFeedback,
                      ),
                    ],
                    if (totalMacros > 0) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Macronutrients',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 180,
                                child: MacroPieChart(macros: macros),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (benefits.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        theme,
                        title: 'Health Benefits',
                        icon: Ionicons.heart_outline,
                        iconColor: Colors.pink.shade300,
                        content: benefits,
                      ),
                    ],
                    if (vitamins.isNotEmpty || minerals.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildNutrientsCard(theme, vitamins, minerals),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        theme,
                        title: 'Notes',
                        icon: Ionicons.bulb_outline,
                        iconColor: _warningOrange, // Use orange for attention
                        content: notes,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (onReset != null)
                      Center(
                        child: FilledButton.icon(
                          icon: const Icon(Ionicons.refresh),
                          label: const Text('Analyze Another'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            textStyle: theme.textTheme.labelLarge,
                          ),
                          onPressed: onReset,
                        ),
                      ),
                    const SizedBox(height: 20),
                  ]
                  .animate(interval: 80.ms)
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.2),
        ),
      ),
    );
  }

  Widget _buildCalorieCard(ThemeData theme, int calories, Color ratingColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ratingColor, Color.lerp(ratingColor, Colors.black, 0.2)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ratingColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Calories',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$calories',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'kcal',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          Icon(
            Ionicons.flame_outline,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientsCard(
    ThemeData theme,
    List<String> vitamins,
    List<String> minerals,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Ionicons.flask_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ), // Used primary blue
                const SizedBox(width: 8),
                Text(
                  'Key Nutrients',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (vitamins.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Vitamins',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: vitamins
                    .map(
                      (v) => Chip(
                        label: Text(v),
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.15,
                        ), // Used primary blue's tint
                        side: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (minerals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Minerals',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: minerals
                    .map(
                      (m) => Chip(
                        label: Text(m),
                        backgroundColor: Colors.orange.shade100.withOpacity(
                          0.3,
                        ), // Using a new consistent color for minerals
                        side: BorderSide(color: Colors.orange.shade100),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativesCard(
    ThemeData theme,
    int healthScore,
    List<Map<String, dynamic>> alternatives,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Ionicons.restaurant_outline,
                  color: _successGreen,
                  size: 24,
                ), // Green for good alternatives
                const SizedBox(width: 8),
                Text(
                  healthScore > 8
                      ? 'Comparable Alternatives'
                      : 'Healthier Alternatives',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: alternatives.map((alt) {
                final name = alt['name'] as String? ?? 'Alternative';
                final reason =
                    alt['reason'] as String? ?? 'No reason provided.';
                final emoji = alt['emoji'] as String? ?? '🥗';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      reason,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Page 2: History (MODIFIED with new score) ---
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<HistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = DatabaseHelper.instance.queryAllRows();
    });
  }

  Future<void> _deleteItem(int id) async {
    final currentList = await _historyFuture;
    final itemToRemove = currentList.firstWhere((item) => item.id == id);

    try {
      final file = File(itemToRemove.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Could not delete image file: $e");
    }

    await DatabaseHelper.instance.delete(id);
    _loadHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${itemToRemove.foodName} removed from history.'),
          backgroundColor: _accentRed, // Use red for deletion
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<HistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data;
          if (items == null || items.isEmpty) {
            return _buildEmptyState(theme);
          }
          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final file = File(item.imagePath);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Dismissible(
                  key: Key(item.id.toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _deleteItem(item.id!),
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Ionicons.trash_outline,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: file.existsSync()
                          ? Image.file(
                              file,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.shade200,
                              child: const Icon(Ionicons.image_outline),
                            ),
                    ),
                    title: Text(
                      item.foodName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${item.calories} kcal • Goal Score: ${item.goalAlignmentScore}/10', // MODIFIED
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Ionicons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoryDetailPage(item: item),
                        ),
                      ).then((_) {
                        _loadHistory();
                      });
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Ionicons.document_text_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text('No History Yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Analyzed items will appear here.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class HistoryDetailPage extends StatelessWidget {
  final HistoryItem item;
  const HistoryDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> nutritionResult =
        jsonDecode(item.fullResponse) as Map<String, dynamic>;
    final File imageFile = File(item.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(item.foodName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !imageFile.existsSync()
          ? Center(
              child: Text(
                'Error: Image file not found.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          : ResultsDisplayWidget(
              nutritionResult: nutritionResult,
              imageFile: imageFile,
              onReset: null,
            ),
    );
  }
}

// --- Page 3: Settings ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(
              Ionicons.person_circle_outline,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              'Update Profile & Goal',
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text('Change your name and personal health goal'),
            trailing: const Icon(Ionicons.chevron_forward),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IntroScreen(isUpdating: true),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- Widgets (HealthScoreIndicator, MacroPieChart) ---

class HealthScoreIndicator extends StatelessWidget {
  final int score;
  const HealthScoreIndicator({super.key, required this.score});

  // MODIFIED to use new constants
  Color _getRatingColor(BuildContext context, int score) {
    if (score >= 8) return _successGreen; // Green for high score
    if (score >= 5) return _warningOrange; // Orange for moderate score
    return _accentRed; // Red for low score
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color scoreColor = _getRatingColor(context, score);

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: CircularPercentIndicator(
            radius: 55.0,
            lineWidth: 10.0,
            percent: score / 10.0,
            animation: true,
            animationDuration: 1000,
            center: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$score',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[100],
                      height: 1.1,
                      fontSize: 50,
                    ),
                  ),
                ],
              ),
            ),
            progressColor: scoreColor,
            backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
            circularStrokeCap: CircularStrokeCap.round,
          ),
        ),
      ),
    );
  }
}

class MacroPieChart extends StatefulWidget {
  final Map<String, dynamic> macros;
  const MacroPieChart({super.key, required this.macros});

  @override
  State<MacroPieChart> createState() => _MacroPieChartState();
}

class _MacroPieChartState extends State<MacroPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final protein = (widget.macros['protein'] as num? ?? 0).toDouble();
    final carbs = (widget.macros['carbs'] as num? ?? 0).toDouble();
    final fat = (widget.macros['fat'] as num? ?? 0).toDouble();
    final total = protein + carbs + fat;

    if (total == 0) {
      return const Center(child: Text("No macro data available."));
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections: _buildSections(total, protein, carbs, fat),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIndicator(
                color: Colors.blue.shade400,
                text: 'Carbs (${carbs.round()}g)',
              ),
              const SizedBox(height: 8),
              _buildIndicator(
                color: Colors.red.shade400,
                text: 'Protein (${protein.round()}g)',
              ),
              const SizedBox(height: 8),
              _buildIndicator(
                color: Colors.amber.shade400,
                text: 'Fat (${fat.round()}g)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(
    double total,
    double protein,
    double carbs,
    double fat,
  ) {
    final bool isTouchedProtein = touchedIndex == 0;
    final bool isTouchedCarbs = touchedIndex == 1;
    final bool isTouchedFat = touchedIndex == 2;

    return [
      PieChartSectionData(
        color: Colors.red.shade400,
        value: protein,
        title: '${(protein / total * 100).round()}%',
        radius: isTouchedProtein ? 60.0 : 50.0,
        titleStyle: TextStyle(
          fontSize: isTouchedProtein ? 16 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
          ],
        ),
      ),
      PieChartSectionData(
        color: Colors.blue.shade400,
        value: carbs,
        title: '${(carbs / total * 100).round()}%',
        radius: isTouchedCarbs ? 60.0 : 50.0,
        titleStyle: TextStyle(
          fontSize: isTouchedCarbs ? 16 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
          ],
        ),
      ),
      PieChartSectionData(
        color: Colors.amber.shade400,
        value: fat,
        title: '${(fat / total * 100).round()}%',
        radius: isTouchedFat ? 60.0 : 50.0,
        titleStyle: TextStyle(
          fontSize: isTouchedFat ? 16 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
          ],
        ),
      ),
    ];
  }

  Widget _buildIndicator({
    required Color color,
    required String text,
    bool isSquare = false,
    double size = 16,
  }) {
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
