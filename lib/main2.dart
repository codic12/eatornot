// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

// --- IMPORTANT SECURITY WARNING ---
// REMOVED API KEY - Replace with your secure method
const String _geminiApiKey = "AIzaSyCdq_4S8X__8VlJD1uo1YP6GlkecrSj-Sw"; // <-- Replace this

void main() {
  if (_geminiApiKey == "YOUR_SECURELY_LOADED_GEMINI_API_KEY" || _geminiApiKey.isEmpty) {
    print("ERROR: Gemini API Key is not set. Please configure it securely.");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6366F1); // Modern indigo
    const accentColor = Color(0xFFEC4899); // Modern pink accent

    final lightTheme = ThemeData(
      colorSchemeSeed: seedColor,
      brightness: Brightness.light,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 28),
        headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 24),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.5),
        bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.5),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );

    final darkTheme = ThemeData(
      colorSchemeSeed: seedColor,
      brightness: Brightness.dark,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 32, color: Colors.white),
        displayMedium: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 28, color: Colors.white),
        headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 24, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.white70),
        bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.5, color: Colors.white70),
        bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.5, color: Colors.white70),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
      ),
    );

    return MaterialApp(
      title: 'NutriSnap',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const FoodAnalyzerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FoodAnalyzerPage extends StatefulWidget {
  const FoodAnalyzerPage({super.key});

  @override
  State<FoodAnalyzerPage> createState() => _FoodAnalyzerPageState();
}

class _FoodAnalyzerPageState extends State<FoodAnalyzerPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _nutritionResult;
  bool _isLoading = false;
  String _errorMessage = '';
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
    if (_geminiApiKey == "YOUR_SECURELY_LOADED_GEMINI_API_KEY" || _geminiApiKey.isEmpty) {
      setState(() {
        _errorMessage = "AI Service not configured.";
        _isLoading = false;
      });
      return;
    }

    final String geminiModel = "gemini-2.5-flash";
    final String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';
    final Uri geminiUrl = Uri.parse('$geminiBaseUrl?key=$_geminiApiKey');

    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final prompt = """
Analyze this food image and provide detailed nutritional information. Be specific and accurate.

Provide your response ONLY in the following JSON format (no markdown):
{
  "foodName": "string (name of the food/dish)",
  "servingSize": "string (estimated serving size, e.g., '1 cup', '200g')",
  "calories": number (total calories),
  "macros": {
    "protein": number (grams),
    "carbs": number (grams),
    "fat": number (grams),
    "fiber": number (grams)
  },
  "vitamins": ["string"] (key vitamins present, e.g., ["Vitamin C", "Vitamin A"]),
  "minerals": ["string"] (key minerals present, e.g., ["Iron", "Calcium"]),
  "healthScore": number (1-10, overall healthiness),
  "tags": ["string"] (dietary tags, e.g., ["Vegetarian", "High Protein", "Low Carb"]),
  "benefits": "string (brief health benefits)",
  "notes": "string (preparation tips or dietary notes)"
}

If you cannot identify the food clearly, set foodName to "Unidentified" and provide your best estimate or explain why.
""";

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
      };

      final response = await http.post(
        geminiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        final candidate = decodedResponse['candidates']?.first;
        final content = candidate?['content'];
        final part = content?['parts']?.first;
        final rawText = part?['text'] as String?;

        if (rawText != null) {
          final cleanedText = rawText.replaceAll(RegExp(r'^```json|```$'), '').trim();

          try {
            final nutritionData = jsonDecode(cleanedText) as Map<String, dynamic>;
            
            if (nutritionData['foodName'] == null) {
              throw const FormatException('Missing required fields in AI response.');
            }
            
            setState(() {
              _nutritionResult = nutritionData;
              _errorMessage = '';
              _isLoading = false;
            });
          } catch (e) {
            debugPrint('Gemini Response JSON Parsing Error: $e\nRaw Text: $cleanedText');
            setState(() {
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
        String apiErrorMsg = 'AI Service Error (${response.statusCode}).';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['error']?['message'] != null) {
            apiErrorMsg = 'AI Error: ${errorBody['error']['message']}';
          }
        } catch (_) {}

        setState(() {
          _errorMessage = apiErrorMsg;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.secondaryContainer.withOpacity(0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: _buildBody(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'NutriSnap',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Snap • Analyze • Eat Smart',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingState(theme);
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState(theme);
    }

    if (_nutritionResult != null) {
      return _buildResultsState(theme);
    }

    return _buildInitialState(theme);
  }

  Widget _buildInitialState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.2),
                          theme.colorScheme.secondary.withOpacity(0.2),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              'Discover What\'s in Your Food',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Take or upload a photo to get instant\nnutritional insights powered by AI',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGradientButton(
          theme: theme,
          icon: Icons.photo_camera_rounded,
          label: 'Camera',
          onPressed: () => _pickImage(ImageSource.camera),
        ),
        const SizedBox(width: 16),
        _buildGradientButton(
          theme: theme,
          icon: Icons.photo_library_rounded,
          label: 'Gallery',
          onPressed: () => _pickImage(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
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
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your food...',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
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
                Icons.error_outline_rounded,
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
            _buildGradientButton(
              theme: theme,
              icon: Icons.refresh_rounded,
              label: 'Try Again',
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                  _imageFile = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsState(ThemeData theme) {
    final data = _nutritionResult!;
    final foodName = data['foodName'] as String? ?? 'Unknown Food';
    final servingSize = data['servingSize'] as String? ?? 'N/A';
    final calories = data['calories'] ?? 0;
    final macros = data['macros'] as Map<String, dynamic>? ?? {};
    final healthScore = data['healthScore'] ?? 5;
    final benefits = data['benefits'] as String? ?? '';
    final tags = (data['tags'] as List?)?.whereType<String>().toList() ?? [];
    final vitamins = (data['vitamins'] as List?)?.whereType<String>().toList() ?? [];
    final minerals = (data['minerals'] as List?)?.whereType<String>().toList() ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFile != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.file(
                    _imageFile!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            
            Text(
              foodName,
              style: theme.textTheme.displayMedium?.copyWith(
                color: theme.colorScheme.primary,
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
                children: tags.map((tag) => _buildTag(theme, tag)).toList(),
              ),
            ],

            const SizedBox(height: 24),
            _buildCalorieCard(theme, calories),

            const SizedBox(height: 16),
            _buildMacrosCard(theme, macros),

            const SizedBox(height: 16),
            _buildHealthScoreCard(theme, healthScore),

            if (benefits.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildBenefitsCard(theme, benefits),
            ],

            if (vitamins.isNotEmpty || minerals.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNutrientsCard(theme, vitamins, minerals),
            ],

            const SizedBox(height: 24),
            Center(
              child: _buildGradientButton(
                theme: theme,
                icon: Icons.photo_camera_rounded,
                label: 'Analyze Another',
                onPressed: () {
                  setState(() {
                    _nutritionResult = null;
                    _imageFile = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(ThemeData theme, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildCalorieCard(ThemeData theme, dynamic calories) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
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
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$calories',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 48,
                ),
              ),
              Text(
                'kcal',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Icon(
            Icons.local_fire_department_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosCard(ThemeData theme, Map<String, dynamic> macros) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macronutrients',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildMacroRow(theme, 'Protein', macros['protein'] ?? 0, Colors.red.shade400),
          const SizedBox(height: 12),
          _buildMacroRow(theme, 'Carbs', macros['carbs'] ?? 0, Colors.blue.shade400),
          const SizedBox(height: 12),
          _buildMacroRow(theme, 'Fat', macros['fat'] ?? 0, Colors.amber.shade400),
          const SizedBox(height: 12),
          _buildMacroRow(theme, 'Fiber', macros['fiber'] ?? 0, Colors.green.shade400),
        ],
      ),
    );
  }

  Widget _buildMacroRow(ThemeData theme, String label, dynamic value, Color color) {
    return Row(
      children: [
        Container(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (value / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 50,
          child: Text(
            '${value}g',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthScoreCard(ThemeData theme, dynamic score) {
    final scoreValue = (score is num) ? score.toInt() : 5;
    final color = scoreValue >= 7
        ? Colors.green.shade400
        : scoreValue >= 4
            ? Colors.orange.shade400
            : Colors.red.shade400;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Score',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  scoreValue >= 7
                      ? 'Excellent choice! 🌟'
                      : scoreValue >= 4
                          ? 'Good balance 👍'
                          : 'Enjoy in moderation ⚠️',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                '$scoreValue',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard(ThemeData theme, String benefits) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: Colors.pink.shade300, size: 24),
              const SizedBox(width: 8),
              Text(
                'Health Benefits',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            benefits,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientsCard(ThemeData theme, List<String> vitamins, List<String> minerals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_rounded, color: Colors.purple.shade300, size: 24),
              const SizedBox(width: 8),
              Text(
                'Key Nutrients',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          if (vitamins.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Vitamins',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vitamins.map((vitamin) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  vitamin,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.purple.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],
          if (minerals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Minerals',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: minerals.map((mineral) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  mineral,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}