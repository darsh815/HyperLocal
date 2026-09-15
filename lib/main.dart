import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_page.dart';
import 'admin_gate.dart';
import 'admin_page.dart';
import 'account_service.dart';
import 'cloud_recipe_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }
  runApp(const LeftoverLabApp());
}

class LeftoverLabApp extends StatelessWidget {
  const LeftoverLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leftover Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F4EC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB94D2F),
          brightness: Brightness.light,
        ),
        fontFamily: 'Georgia',
      ),
      // Start directly in the kitchen: signing in is optional and available
      // from the profile button, so a hungry visitor can begin in one tap.
      home: Uri.base.path.replaceFirst(RegExp(r'/$'), '') == '/admin'
          ? const AdminGate()
          : const AccountRoleGate(),
    );
  }
}

class AccountRoleGate extends StatefulWidget {
  const AccountRoleGate({super.key});

  @override
  State<AccountRoleGate> createState() => _AccountRoleGateState();
}

class _AccountRoleGateState extends State<AccountRoleGate> {
  final _accountService = AccountService();
  AccountSession? _session;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await _accountService.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isCheckingSession = false;
    });
  }

  @override
  void dispose() {
    _accountService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session?.isAdmin == true) {
      return AdminPage(accountService: _accountService, session: session!);
    }
    return const RecipeHomePage();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _accountService = AccountService();
  AccountSession? _session;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _accountService.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _accountService.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isCheckingSession = false;
    });
  }

  Future<void> _handleSignIn(AccountSession session) async {
    await _accountService.saveSession(session);
    if (mounted) setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F4EC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session != null) return const RecipeHomePage();

    return AccountPage(
      accountService: _accountService,
      session: null,
      closeAfterSignIn: false,
      closeAfterGuest: false,
      onSignedIn: _handleSignIn,
      onSignedOut: () async {},
      onContinueAsGuest: () async {
        if (mounted) {
          setState(
            () => _session = const AccountSession(token: '', email: 'Guest'),
          );
        }
      },
    );
  }
}

class PantryItem {
  const PantryItem(this.name, this.category, this.icon);

  final String name;
  final String category;
  final IconData icon;
}

class GeneratedRecipe {
  const GeneratedRecipe({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.steps,
    required this.accent,
    required this.ecoScore,
    required this.tutorialSearchQuery,
  });

  final String title;
  final String subtitle;
  final String time;
  final List<String> steps;
  final Color accent;
  final int ecoScore;
  final String tutorialSearchQuery;
}

class SavedRecipe {
  const SavedRecipe({this.id, required this.recipe, required this.savedAt});

  final String? id;
  final GeneratedRecipe recipe;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': recipe.title,
    'subtitle': recipe.subtitle,
    'time': recipe.time,
    'steps': recipe.steps,
    'accent': recipe.accent.toARGB32(),
    'ecoScore': recipe.ecoScore,
    'tutorialSearchQuery': recipe.tutorialSearchQuery,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedRecipe.fromJson(Map<String, dynamic> json) => SavedRecipe(
    id: json['id'] as String?,
    recipe: GeneratedRecipe(
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      time: json['time'] as String,
      steps: (json['steps'] as List).whereType<String>().toList(),
      accent: Color(json['accent'] as int),
      ecoScore: (json['ecoScore'] as num?)?.toInt() ?? 60,
      tutorialSearchQuery:
          json['tutorialSearchQuery'] as String? ??
          '${json['title'] as String} recipe',
    ),
    savedAt: DateTime.parse((json['savedAt'] ?? json['created_at']) as String),
  );
}

const pantry = [
  PantryItem('Rice', 'Staples', Icons.rice_bowl_outlined),
  PantryItem('Pasta', 'Staples', Icons.ramen_dining_outlined),
  PantryItem('Eggs', 'Protein', Icons.egg_alt_outlined),
  PantryItem('Chicken', 'Protein', Icons.set_meal_outlined),
  PantryItem('Chickpeas', 'Protein', Icons.circle_outlined),
  PantryItem('Spinach', 'Produce', Icons.eco_outlined),
  PantryItem('Tomatoes', 'Produce', Icons.spa_outlined),
  PantryItem('Carrots', 'Produce', Icons.local_florist_outlined),
  PantryItem('Onion', 'Produce', Icons.grass_outlined),
  PantryItem('Cheese', 'Dairy', Icons.local_pizza_outlined),
  PantryItem('Yogurt', 'Dairy', Icons.icecream_outlined),
  PantryItem('Bread', 'Staples', Icons.bakery_dining_outlined),
];

class RecipeHomePage extends StatefulWidget {
  const RecipeHomePage({super.key});

  @override
  State<RecipeHomePage> createState() => _RecipeHomePageState();
}

class _RecipeHomePageState extends State<RecipeHomePage> {
  final _customIngredientController = TextEditingController();
  final _cloudRecipeService = CloudRecipeService();
  final _accountService = AccountService();
  // Let the first action reflect what is actually left in the user's fridge.
  final _selectedIngredients = <String>{};
  final _customPantryItems = <PantryItem>[];
  final _savedRecipes = <SavedRecipe>[];
  static const _historyStorageKey = 'saved_recipes';
  String _activeCategory = 'All';
  GeneratedRecipe? _recipe;
  bool _isGenerating = false;
  bool _isRecognizing = false;
  String _dietaryPreference = 'Any diet';
  String _recipeLanguage = 'English';
  int _servings = 2;
  int _maxMinutes = 30;
  AccountSession? _accountSession;

  final _categories = const ['All', 'Staples', 'Protein', 'Produce', 'Dairy'];

  @override
  void initState() {
    super.initState();
    _loadSavedRecipes();
    _restoreAccount();
  }

  @override
  void dispose() {
    _customIngredientController.dispose();
    _cloudRecipeService.dispose();
    _accountService.dispose();
    super.dispose();
  }

  List<PantryItem> get _visiblePantry {
    final items = [...pantry, ..._customPantryItems];
    if (_activeCategory == 'All') return items;
    return items.where((item) => item.category == _activeCategory).toList();
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (!_selectedIngredients.remove(ingredient)) {
        _selectedIngredients.add(ingredient);
      }
      _recipe = null;
    });
  }

  void _addCustomIngredient() {
    final rawIngredient = _customIngredientController.text.trim();
    if (rawIngredient.isEmpty) return;

    final ingredient =
        rawIngredient[0].toUpperCase() + rawIngredient.substring(1);
    final alreadyListed = [
      ...pantry,
      ..._customPantryItems,
    ].any((item) => item.name.toLowerCase() == ingredient.toLowerCase());

    setState(() {
      if (!alreadyListed) {
        _customPantryItems.add(
          PantryItem(ingredient, 'Custom', Icons.kitchen_outlined),
        );
      }
      _selectedIngredients.add(ingredient);
      _customIngredientController.clear();
      _activeCategory = 'All';
      _recipe = null;
    });
  }

  Future<void> _recognizeIngredients() async {
    if (_isRecognizing) return;
    if (!_cloudRecipeService.isRecognitionConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera AI is not connected. Launch with AI_RECOGNIZE_ENDPOINT.',
          ),
        ),
      );
      return;
    }

    setState(() => _isRecognizing = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final recognized = await _cloudRecipeService.recognizeIngredients(
        await image.readAsBytes(),
        mimeType: image.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;

      if (recognized.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ingredients were recognized.')),
        );
        return;
      }

      setState(() {
        for (final rawIngredient in recognized) {
          final ingredient =
              rawIngredient[0].toUpperCase() + rawIngredient.substring(1);
          final alreadyListed = [
            ...pantry,
            ..._customPantryItems,
          ].any((item) => item.name.toLowerCase() == ingredient.toLowerCase());
          if (!alreadyListed) {
            _customPantryItems.add(
              PantryItem(ingredient, 'Custom', Icons.kitchen_outlined),
            );
          }
          _selectedIngredients.add(ingredient);
        }
        _activeCategory = 'All';
        _recipe = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${recognized.length} ingredients.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not use the camera: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  Future<void> _generateRecipe() async {
    final ingredients = _selectedIngredients.toList()..sort();
    if (ingredients.isEmpty || _isGenerating) return;

    setState(() => _isGenerating = true);
    try {
      final cloudRecipe = await _cloudRecipeService.generate(
        ingredients,
        dietaryPreference: _dietaryPreference,
        servings: _servings,
        maxMinutes: _maxMinutes,
        language: _recipeLanguage,
      );
      if (cloudRecipe != null && mounted) {
        setState(() {
          _recipe = GeneratedRecipe(
            title: cloudRecipe.title,
            subtitle: cloudRecipe.subtitle,
            time: cloudRecipe.time,
            steps: cloudRecipe.steps,
            accent: const Color(0xFF2E5D50),
            ecoScore: _ecoScore(ingredients, cloudRecipe.time),
            tutorialSearchQuery: cloudRecipe.tutorialSearchQuery,
          );
          _isGenerating = false;
        });
        return;
      }
    } catch (error) {
      if (mounted) {
        final detail = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _cloudRecipeService.isConfigured
                  ? 'Cloud AI request failed at ${CloudRecipeService.endpoint}: $detail'
                  : 'Cloud AI is not connected. Start the server and launch with AI_RECIPE_ENDPOINT.',
            ),
          ),
        );
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    bool has(String item) => ingredients.contains(item);
    final base = has('Rice')
        ? 'rice'
        : has('Pasta')
        ? 'pasta'
        : has('Bread')
        ? 'toast'
        : 'skillet';
    final green = has('Spinach')
        ? 'green'
        : has('Carrots')
        ? 'bright'
        : 'golden';
    final protein = has('Chicken')
        ? 'chicken'
        : has('Chickpeas')
        ? 'chickpea'
        : has('Eggs')
        ? 'egg'
        : 'garden';
    final finish = has('Cheese')
        ? 'with a bubbling cheese finish'
        : has('Yogurt')
        ? 'with a cool yogurt spoon'
        : 'with a sharp, fresh finish';

    final recipe = GeneratedRecipe(
      title: '${_titleCase(green)} $protein $base',
      subtitle: 'A one-pan idea built from ${ingredients.join(', ')} $finish.',
      time: ingredients.length > 5
          ? '25 min'
          : '${11 + ingredients.length * 2} min',
      accent: has('Spinach')
          ? const Color(0xFF6C8752)
          : has('Tomatoes')
          ? const Color(0xFFD46A32)
          : has('Cheese')
          ? const Color(0xFFC28A29)
          : const Color(0xFF2E5D50),
      steps: [
        'Start with onion, carrots, or your firmest ingredient in a hot pan until fragrant.',
        'Add ${ingredients.take(3).join(', ')} and cook until the edges turn golden.',
        'Fold in the $base and loosen with a splash of water, stock, or pasta water.',
        'Taste, season, and finish $finish. Serve while the pan is still singing.',
      ],
      tutorialSearchQuery: '${_titleCase(green)} $protein $base recipe',
      ecoScore: _ecoScore(
        ingredients,
        ingredients.length > 5
            ? '25 min'
            : '${11 + ingredients.length * 2} min',
      ),
    );

    setState(() {
      _recipe = recipe;
      _isGenerating = false;
    });
  }

  int _ecoScore(List<String> ingredients, String time) {
    final produce = ingredients
        .where(
          (ingredient) =>
              ['Spinach', 'Tomatoes', 'Carrots', 'Onion'].contains(ingredient),
        )
        .length;
    final minutes =
        int.tryParse(RegExp(r'\d+').firstMatch(time)?.group(0) ?? '') ?? 30;
    return (42 +
            (ingredients.length * 7).clamp(0, 35) +
            produce * 6 +
            (minutes <= 20 ? 8 : 3))
        .clamp(0, 100);
  }

  Future<void> _loadSavedRecipes() async {
    final preferences = await SharedPreferences.getInstance();
    final savedJson = preferences.getString(_historyStorageKey);
    if (savedJson == null || !mounted) return;

    try {
      final decoded = jsonDecode(savedJson) as List<dynamic>;
      setState(() {
        _savedRecipes
          ..clear()
          ..addAll(
            decoded.whereType<Map<String, dynamic>>().map(SavedRecipe.fromJson),
          );
      });
    } catch (_) {
      await preferences.remove(_historyStorageKey);
    }
  }

  Future<void> _restoreAccount() async {
    final session = await _accountService.restoreSession();
    if (session == null || !mounted) return;
    setState(() => _accountSession = session);
    await _loadCloudHistory(session);
  }

  Future<void> _loadCloudHistory(AccountSession session) async {
    if (!_accountService.isConfigured) return;
    try {
      final localRecipes = _savedRecipes
          .where((saved) => saved.id == null)
          .toList();
      for (final saved in localRecipes) {
        await _accountService.saveRecipe(session.token, saved.toJson());
      }
      final recipes = await _accountService.loadHistory(session.token);
      if (!mounted) return;
      setState(() {
        _savedRecipes
          ..clear()
          ..addAll(recipes.map(SavedRecipe.fromJson));
      });
    } catch (_) {
      // Local history remains available when the API is offline.
    }
  }

  Future<void> _persistSavedRecipes() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _historyStorageKey,
      jsonEncode(_savedRecipes.map((saved) => saved.toJson()).toList()),
    );
  }

  Future<void> _saveCurrentRecipe() async {
    final recipe = _recipe;
    if (recipe == null) return;
    final isAlreadySaved = _savedRecipes.any(
      (saved) =>
          saved.recipe.title == recipe.title &&
          saved.recipe.subtitle == recipe.subtitle,
    );
    if (isAlreadySaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This recipe is already in your history.'),
        ),
      );
      return;
    }

    var saved = SavedRecipe(recipe: recipe, savedAt: DateTime.now());
    final session = _accountSession;
    if (session != null) {
      try {
        final documentId = await _accountService.saveRecipe(
          session.token,
          saved.toJson(),
        );
        saved = SavedRecipe(
          id: documentId,
          recipe: recipe,
          savedAt: saved.savedAt,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved locally, but cloud sync failed: $error'),
            ),
          );
        }
      }
    }
    setState(() => _savedRecipes.insert(0, saved));
    await _persistSavedRecipes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved to your history.')),
      );
    }
  }

  Future<void> _deleteSavedRecipe(SavedRecipe saved) async {
    setState(() => _savedRecipes.remove(saved));
    await _persistSavedRecipes();
    final session = _accountSession;
    if (session != null && saved.id != null) {
      await _accountService.deleteRecipe(session.token, saved.id!);
    }
  }

  Future<void> _showAccountPage({bool initiallyRegistering = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AccountPage(
          accountService: _accountService,
          session: _accountSession,
          closeAfterSignIn: false,
          initiallyRegistering: initiallyRegistering,
          onSignedIn: (session) async {
            await _accountService.saveSession(session);
            if (!mounted) return;
            setState(() => _accountSession = session);
            if (session.isAdmin) {
              await Navigator.of(context).pushAndRemoveUntil<void>(
                MaterialPageRoute(
                  builder: (_) => AdminPage(
                    accountService: _accountService,
                    session: session,
                  ),
                ),
                (route) => false,
              );
              return;
            }
            await _loadCloudHistory(session);
            if (mounted) Navigator.pop(context);
          },
          onSignedOut: () async {
            await _accountService.clearSession();
            if (mounted) setState(() => _accountSession = null);
          },
          onContinueAsGuest: () async {},
        ),
      ),
    );
  }

  void _clearSelection() {
    if (_selectedIngredients.isEmpty) return;
    setState(() {
      _selectedIngredients.clear();
      _recipe = null;
    });
  }

  void _selectVisibleIngredients() {
    setState(() {
      _selectedIngredients.addAll(_visiblePantry.map((item) => item.name));
      _recipe = null;
    });
  }

  Future<void> _openTutorial(GeneratedRecipe recipe) async {
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': recipe.tutorialSearchQuery,
    });
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the recipe tutorial.')),
      );
    }
  }

  Future<void> _copyCurrentRecipe() async {
    final recipe = _recipe;
    if (recipe == null) return;

    final recipeText = [
      recipe.title,
      recipe.subtitle,
      'Time: ${recipe.time}',
      'Eco impact: ${recipe.ecoScore}/100',
      '',
      ...recipe.steps.asMap().entries.map(
        (entry) => '${entry.key + 1}. ${entry.value}',
      ),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: recipeText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe copied to your clipboard.')),
      );
    }
  }

  void _showSavedRecipes() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Saved recipes',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_savedRecipes.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            setState(() => _savedRecipes.clear());
                            setSheetState(() {});
                            await _persistSavedRecipes();
                          },
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _savedRecipes.isEmpty
                        ? const Center(
                            child: Text(
                              'Save a generated recipe and it will appear here.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: _savedRecipes.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final saved = _savedRecipes[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(saved.recipe.title),
                                subtitle: Text(
                                  '${saved.recipe.time} · ${saved.recipe.subtitle}',
                                ),
                                onTap: () {
                                  setState(() => _recipe = saved.recipe);
                                  Navigator.pop(context);
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove recipe',
                                  onPressed: () async {
                                    await _deleteSavedRecipe(saved);
                                    setSheetState(() {});
                                  },
                                ),
                              );
                            },
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

  void _showAboutAndContact() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Leftover Lab'),
        content: const Text(
          'Leftover Lab turns the ingredients already in your kitchen into practical meal ideas, helping you waste less and cook with confidence.\n\nNeed help or want to share feedback? Contact us at hello@leftoverlab.app.',
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: 'hello@leftoverlab.app'),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact email copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy email'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 54 : 20,
                vertical: 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 42),
                      _buildIntro(),
                      const SizedBox(height: 28),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPantry()),
                            const SizedBox(width: 28),
                            Expanded(child: _buildRecipeCard()),
                          ],
                        )
                      else ...[
                        _buildPantry(),
                        const SizedBox(height: 24),
                        _buildRecipeCard(),
                      ],
                      const SizedBox(height: 28),
                      _buildTip(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFB94D2F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.soup_kitchen_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'LEFTOVER LAB',
          style: TextStyle(
            color: Color(0xFFB94D2F),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.1,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _showSavedRecipes,
          tooltip: 'Your saved recipes',
          icon: const Icon(Icons.bookmark_border_rounded),
        ),
        if (_savedRecipes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              '${_savedRecipes.length}',
              style: TextStyle(
                color: Colors.brown.shade500,
                fontFamily: 'sans-serif',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        IconButton(
          onPressed: _showAccountPage,
          tooltip: _accountSession == null ? 'Register or sign in' : 'Account',
          icon: Icon(
            _accountSession == null
                ? Icons.person_outline_rounded
                : Icons.person_rounded,
          ),
        ),
        IconButton(
          onPressed: _showAboutAndContact,
          tooltip: 'About and contact',
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Make dinner\nfrom what is left.',
          style: TextStyle(
            color: Color(0xFF29251F),
            fontSize: 46,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Tap what is in your fridge, add anything missing, and get a fast recipe that helps rescue good food from the bin.',
          style: TextStyle(
            color: Colors.brown.shade400,
            fontFamily: 'sans-serif',
            fontSize: 16,
            height: 1.45,
          ),
        ),
        if (_accountSession == null) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _showAccountPage,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Sign in'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E5D50),
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton(
                onPressed: () => _showAccountPage(initiallyRegistering: true),
                child: const Text('Create account'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPantry() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9DFD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'What do you have?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              if (_selectedIngredients.isNotEmpty)
                TextButton(
                  onPressed: _clearSelection,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB94D2F),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Clear'),
                ),
              Text(
                '${_selectedIngredients.length} selected',
                style: TextStyle(
                  color: Colors.brown.shade400,
                  fontFamily: 'sans-serif',
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _activeCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => _activeCategory = category),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF655A4E),
                    fontFamily: 'sans-serif',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: const Color(0xFF2E5D50),
                  backgroundColor: const Color(0xFFF3EEE6),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton.icon(
                onPressed: _selectVisibleIngredients,
                icon: const Icon(Icons.done_all, size: 17),
                label: Text(
                  _activeCategory == 'All'
                      ? 'Select all'
                      : 'Select all $_activeCategory',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2E5D50),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _visiblePantry.map(_ingredientChip).toList(),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _customIngredientController,
                  onSubmitted: (_) => _addCustomIngredient(),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Add another ingredient...',
                    hintStyle: TextStyle(
                      color: Colors.brown.shade300,
                      fontFamily: 'sans-serif',
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.add, size: 20),
                    suffixIcon: IconButton(
                      onPressed: _addCustomIngredient,
                      tooltip: 'Add ingredient',
                      icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F4EC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isRecognizing ? null : _recognizeIngredients,
                tooltip: 'Recognize ingredients with camera',
                icon: _isRecognizing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2E5D50),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB9C8C2),
                  minimumSize: const Size(52, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildRecipePreferences(),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _selectedIngredients.isEmpty || _isGenerating
                  ? null
                  : _generateRecipe,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 19),
              label: Text(
                _isGenerating ? 'Asking cloud AI...' : 'Generate my recipe',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB94D2F),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipePreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tune the result',
          style: TextStyle(
            color: Colors.brown.shade500,
            fontFamily: 'sans-serif',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _dietaryPreference,
                borderRadius: BorderRadius.circular(12),
                items: const ['Any diet', 'Vegetarian', 'Vegan', 'High protein']
                    .map(
                      (diet) =>
                          DropdownMenuItem(value: diet, child: Text(diet)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _dietaryPreference = value ?? _dietaryPreference;
                  _recipe = null;
                }),
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _recipeLanguage,
                borderRadius: BorderRadius.circular(12),
                items: const ['English', 'Hindi', 'Spanish', 'French', 'Arabic']
                    .map(
                      (language) => DropdownMenuItem(
                        value: language,
                        child: Text(language),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _recipeLanguage = value ?? _recipeLanguage;
                  _recipe = null;
                }),
              ),
            ),
            ChoiceChip(
              label: Text('$_servings servings'),
              selected: false,
              onSelected: (_) => setState(() {
                _servings = _servings == 4 ? 1 : _servings + 1;
                _recipe = null;
              }),
              showCheckmark: false,
            ),
            ChoiceChip(
              label: Text('Under $_maxMinutes min'),
              selected: false,
              onSelected: (_) => setState(() {
                _maxMinutes = _maxMinutes == 45 ? 15 : _maxMinutes + 15;
                _recipe = null;
              }),
              showCheckmark: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _ingredientChip(PantryItem item) {
    final selected = _selectedIngredients.contains(item.name);
    return InkWell(
      onTap: () => _toggleIngredient(item.name),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F0E9) : const Color(0xFFF8F4EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF6C8752) : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 19,
              color: selected
                  ? const Color(0xFF2E5D50)
                  : const Color(0xFF857669),
            ),
            const SizedBox(width: 7),
            Text(
              item.name,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF2E5D50)
                    : const Color(0xFF655A4E),
                fontFamily: 'sans-serif',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 15, color: Color(0xFF2E5D50)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard() {
    final recipe = _recipe;
    return Container(
      constraints: const BoxConstraints(minHeight: 430),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: recipe == null
              ? const [Color(0xFF2E5D50), Color(0xFF173D36)]
              : [
                  recipe.accent,
                  Color.lerp(recipe.accent, const Color(0xFF172F2A), .62)!,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (recipe?.accent ?? const Color(0xFF2E5D50)).withValues(
              alpha: .18,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: recipe == null
          ? _buildEmptyRecipeState()
          : _buildGeneratedRecipe(recipe),
    );
  }

  Widget _buildEmptyRecipeState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 25),
        ),
        const SizedBox(height: 28),
        const Text(
          'Your next meal\nis hiding in plain sight.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pick a few ingredients and let the smart kitchen do the connecting.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontFamily: 'sans-serif',
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedRecipe(GeneratedRecipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  SizedBox(width: 7),
                  Text(
                    'SMART RECIPE',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'sans-serif',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC).withValues(alpha: .94),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, color: recipe.accent, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    recipe.time,
                    style: TextStyle(
                      color: recipe.accent,
                      fontFamily: 'sans-serif',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          recipe.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            height: 1.02,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          recipe.subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontFamily: 'sans-serif',
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        _buildEcoImpact(recipe),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              color: Colors.white.withValues(alpha: .66),
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              'THE METHOD',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .66),
                fontFamily: 'sans-serif',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...recipe.steps.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'sans-serif',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'sans-serif',
                        fontSize: 13,
                        height: 1.38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _saveCurrentRecipe,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save recipe'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .14),
                side: BorderSide(color: Colors.white.withValues(alpha: .30)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openTutorial(recipe),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Watch tutorial'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: .30)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _copyCurrentRecipe,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: .30)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEcoImpact(GeneratedRecipe recipe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_outlined, color: Color(0xFFD8E7B8), size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Saves food waste',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .88),
                fontFamily: 'sans-serif',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${recipe.ecoScore}/100',
            style: const TextStyle(
              color: Color(0xFFD8E7B8),
              fontFamily: 'sans-serif',
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb_outline_rounded,
          color: Color(0xFFB94D2F),
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Kitchen note: the best leftover recipes are flexible. Taste as you go, swap freely, and trust your instincts.',
            style: TextStyle(
              color: Colors.brown.shade400,
              fontFamily: 'sans-serif',
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
