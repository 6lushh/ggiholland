import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

// ==================== THEME ====================
class AppTheme {
  static const Color primary = Color(0xFFE50000); // GGI Rood
  static const Color background = Color(0xFF121212); // Zwart
  static const Color surface = Color(0xFF1E1E1E); // Donkergrijs
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color border = Color(0xFF333333);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGI Holland - Stieradvies',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.primary,
          surface: AppTheme.surface,
          background: AppTheme.background,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppTheme.textPrimary),
          bodyMedium: TextStyle(color: AppTheme.textPrimary),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== DATAMODEL ====================
class KoeAdvies {
  final String koe;
  final String levensnummer;
  final String triple;
  final String advies1;
  final String advies2;
  final String advies3;
  final String? kiCode1;
  final String? kiCode2;
  final String? kiCode3;
  final DateTime zoekDatum;

  KoeAdvies({
    required this.koe,
    required this.levensnummer,
    required this.triple,
    required this.advies1,
    required this.advies2,
    required this.advies3,
    this.kiCode1,
    this.kiCode2,
    this.kiCode3,
    required this.zoekDatum,
  });

  Map<String, dynamic> toJson() => {
        'koe': koe,
        'levensnummer': levensnummer,
        'triple': triple,
        'advies1': advies1,
        'advies2': advies2,
        'advies3': advies3,
        'kiCode1': kiCode1,
        'kiCode2': kiCode2,
        'kiCode3': kiCode3,
        'zoekDatum': zoekDatum.toIso8601String(),
      };

  factory KoeAdvies.fromJson(Map<String, dynamic> json) => KoeAdvies(
        koe: json['koe'] ?? '',
        levensnummer: json['levensnummer'] ?? '',
        triple: json['triple'] ?? '',
        advies1: json['advies1'] ?? '',
        advies2: json['advies2'] ?? '',
        advies3: json['advies3'] ?? '',
        kiCode1: json['kiCode1'],
        kiCode2: json['kiCode2'],
        kiCode3: json['kiCode3'],
        zoekDatum: DateTime.parse(json['zoekDatum']),
      );
}

// ==================== STORAGE SERVICE ====================
class StorageService {
  static const String _geschiedenisKey = 'zoek_geschiedenis';
  static const String _favorietenKey = 'favorieten';
  static const String _xmlDataKey = 'opgeslagen_xml';
  static const String _xmlPadKey = 'xml_bestand_pad';

  static Future<void> saveXmlData(List<Map<String, String>> xmlData, String bestandPad) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = xmlData.map((row) => jsonEncode(row)).toList();
    await prefs.setStringList(_xmlDataKey, jsonList);
    await prefs.setString(_xmlPadKey, bestandPad);
  }

  static Future<List<Map<String, String>>?> getXmlData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_xmlDataKey);
    if (jsonList == null) return null;
    return jsonList.map((json) => Map<String, String>.from(jsonDecode(json))).toList();
  }

  static Future<String?> getXmlPad() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_xmlPadKey);
  }

  static Future<void> clearXmlData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_xmlDataKey);
    await prefs.remove(_xmlPadKey);
  }

  static Future<void> saveZoekopdracht(KoeAdvies advies) async {
    final prefs = await SharedPreferences.getInstance();
    List<KoeAdvies> geschiedenis = await getGeschiedenis();
    geschiedenis.removeWhere((g) => g.koe == advies.koe);
    geschiedenis.insert(0, advies);
    if (geschiedenis.length > 50) geschiedenis = geschiedenis.sublist(0, 50);
    final jsonList = geschiedenis.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_geschiedenisKey, jsonList);
  }

  static Future<List<KoeAdvies>> getGeschiedenis() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_geschiedenisKey) ?? [];
    return jsonList.map((json) => KoeAdvies.fromJson(jsonDecode(json))).toList();
  }

  static Future<void> clearGeschiedenis() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geschiedenisKey);
  }

  static Future<void> toggleFavoriet(KoeAdvies advies) async {
    final prefs = await SharedPreferences.getInstance();
    List<KoeAdvies> favorieten = await getFavorieten();
    if (favorieten.any((f) => f.koe == advies.koe)) {
      favorieten.removeWhere((f) => f.koe == advies.koe);
    } else {
      favorieten.add(advies);
    }
    final jsonList = favorieten.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_favorietenKey, jsonList);
  }

  static Future<List<KoeAdvies>> getFavorieten() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_favorietenKey) ?? [];
    return jsonList.map((json) => KoeAdvies.fromJson(jsonDecode(json))).toList();
  }

  static Future<bool> isFavoriet(String koeNummer) async {
    final favorieten = await getFavorieten();
    return favorieten.any((f) => f.koe == koeNummer);
  }
}

// ==================== SPLASH SCREEN ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Reset de v13_cleared flag om data te clearen
    _checkDataAndNavigate();
  }

  Future<void> _checkDataAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCleared = prefs.getBool('v15_cleared') ?? false;

    if (!hasCleared) {
      await StorageService.clearXmlData();
      await StorageService.clearGeschiedenis();
      await prefs.remove(StorageService._favorietenKey);
      await prefs.setBool('v15_cleared', true);
    }

    final opgeslagenXml = await StorageService.getXmlData();

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      if (opgeslagenXml != null && opgeslagenXml.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(xmlData: opgeslagenXml),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const StartScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Image.asset('assets/icon.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================== STARTSCHERM ====================
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  Future<void> _pickXmlFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String xmlString = await file.readAsString();
      
      List<Map<String, String>> parsedData = [];
      try {
        final document = XmlDocument.parse(xmlString);
        final cows = document.findAllElements('cows');
        for (var cow in cows) {
          String rawEarTag = cow.findElements('EarTag').firstOrNull?.innerText ?? '';
          String digitsOnly = rawEarTag.replaceAll(RegExp(r'\D'), '');
          String werknummer = '';
          if (digitsOnly.length >= 8) {
            werknummer = digitsOnly.substring(4, 8);
          } else {
            werknummer = digitsOnly;
          }

          parsedData.add({
            'CowNumber': cow.findElements('CowNumber').firstOrNull?.innerText ?? '',
            'EarTag': rawEarTag,
            'Werknummer': werknummer,
            'Triple': cow.findElements('triple').firstOrNull?.innerText ?? cow.findElements('Triple').firstOrNull?.innerText ?? cow.findElements('TripleA').firstOrNull?.innerText ?? '',
            'Sire': cow.findElements('Sire').firstOrNull?.innerText ?? '',
            'NameBull1': cow.findElements('NameBull1').firstOrNull?.innerText ?? '',
            'NameBull2': cow.findElements('NameBull2').firstOrNull?.innerText ?? '',
            'NameBull3': cow.findElements('NameBull3').firstOrNull?.innerText ?? '',
            'AICodeBull1': cow.findElements('AICodeBull1').firstOrNull?.innerText ?? '',
            'AICodeBull2': cow.findElements('AICodeBull2').firstOrNull?.innerText ?? '',
            'AICodeBull3': cow.findElements('AICodeBull3').firstOrNull?.innerText ?? '',
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fout bij inlezen XML: $e')),
          );
        }
        return;
      }

      await StorageService.saveXmlData(parsedData, result.files.single.path!);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(xmlData: parsedData),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Image.asset('assets/icon.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Welkom bij GGI Holland',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecteer het paringsadvies XML-bestand om te beginnen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 50),
                ElevatedButton.icon(
                  onPressed: () => _pickXmlFile(context),
                  icon: const Icon(Icons.upload_file, size: 28, color: Colors.white),
                  label: const Text(
                    'XML-bestand selecteren',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== MAIN SCREEN MET TABS ====================
class MainScreen extends StatefulWidget {
  final List<Map<String, String>> xmlData;

  const MainScreen({super.key, required this.xmlData});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          SearchScreen(xmlData: widget.xmlData),
          const GeschiedenisScreen(),
          const FavorietenScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.background,
        indicatorColor: AppTheme.primary.withOpacity(0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search, color: Colors.white70),
            selectedIcon: Icon(Icons.search, color: AppTheme.primary),
            label: 'Zoeken',
          ),
          NavigationDestination(
            icon: Icon(Icons.history, color: Colors.white70),
            selectedIcon: Icon(Icons.history, color: AppTheme.primary),
            label: 'Geschiedenis',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite, color: Colors.white70),
            selectedIcon: Icon(Icons.favorite, color: AppTheme.primary),
            label: 'Favorieten',
          ),
        ],
      ),
    );
  }
}

// ==================== GEMEENSCHAPPELIJKE APPBAR ====================
AppBar buildGGIAppBar(BuildContext context, {required VoidCallback onNieuwXml}) {
  return AppBar(
    title: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset('assets/icon.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Stieradvies',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    ),
    backgroundColor: AppTheme.background,
    foregroundColor: AppTheme.textPrimary,
    actions: [
      IconButton(
        onPressed: onNieuwXml,
        icon: const Icon(Icons.swap_horiz, color: AppTheme.textSecondary),
        tooltip: 'Nieuw XML-bestand',
      ),
    ],
  );
}

// ==================== AUTOCOMPLETE ZOEKSCHERM ====================
class SearchScreen extends StatefulWidget {
  final List<Map<String, String>> xmlData;

  const SearchScreen({super.key, required this.xmlData});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _searchFieldKey = GlobalKey();
  Map<String, dynamic>? _result;
  bool _isFavoriet = false;
  OverlayEntry? _overlayEntry;
  bool _searchByWerknummer = false;

  void _onSearchChanged(String query) {
    _hideDropdown();

    if (query.isEmpty) {
      setState(() {
        _result = null;
      });
      return;
    }

    final String searchKey = _searchByWerknummer ? 'Werknummer' : 'CowNumber';

    final matches = widget.xmlData.where((cow) {
      return cow[searchKey]?.startsWith(query) ?? false;
    }).take(5).toList();

    if (matches.isNotEmpty) {
      _showDropdown(matches);
    }
  }

  void _showDropdown(List<Map<String, String>> matches) {
    if (!mounted) return;
    _hideDropdown();

    final RenderBox renderBox = _searchFieldKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 5,
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.surface,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: matches.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final match = matches[index];
                return ListTile(
                  title: Text(
                    _searchByWerknummer 
                        ? 'Werknummer: ${match['Werknummer']} (Halsband: ${match['CowNumber']})'
                        : 'Halsband: ${match['CowNumber']} (Werknummer: ${match['Werknummer']})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  subtitle: Text('Stier: ${match['Sire']}', style: const TextStyle(color: AppTheme.textSecondary)),
                  onTap: () {
                    _hideDropdown();
                    _searchController.text = _searchByWerknummer ? match['Werknummer'] ?? '' : match['CowNumber'] ?? '';
                    _selectCow(match);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _selectCow(Map<String, String> cow) async {
    final advies = KoeAdvies(
      koe: cow['CowNumber'] ?? '',
      levensnummer: cow['EarTag'] ?? '',
      triple: cow['Triple'] ?? '',
      advies1: cow['NameBull1'] ?? '',
      advies2: cow['NameBull2'] ?? '',
      advies3: cow['NameBull3'] ?? '',
      kiCode1: cow['AICodeBull1'],
      kiCode2: cow['AICodeBull2'],
      kiCode3: cow['AICodeBull3'],
      zoekDatum: DateTime.now(),
    );

    setState(() {
      _result = advies.toJson();
    });
    FocusScope.of(context).unfocus();

    await StorageService.saveZoekopdracht(advies);
    final isFav = await StorageService.isFavoriet(advies.koe);
    setState(() {
      _isFavoriet = isFav;
    });
  }

  Future<void> _toggleFavoriet() async {
    if (_result == null) return;
    
    final advies = KoeAdvies.fromJson(_result!);
    await StorageService.toggleFavoriet(advies);
    
    final isFav = await StorageService.isFavoriet(advies.koe);
    setState(() {
      _isFavoriet = isFav;
    });
  }

  void _nieuwXmlSelecteren() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const StartScreen()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _hideDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: buildGGIAppBar(context, onNieuwXml: _nieuwXmlSelecteren),
      body: GestureDetector(
        onTap: () {
          _hideDropdown();
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Halsband'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Werknummer'),
                  ),
                ],
                selected: {_searchByWerknummer},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _searchByWerknummer = newSelection.first;
                    _onSearchChanged(_searchController.text);
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: AppTheme.textPrimary,
                  selectedBackgroundColor: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: _searchFieldKey,
                controller: _searchController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: _searchByWerknummer ? 'Werknummer' : 'Halsband',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  hintText: _searchByWerknummer ? 'Begin met typen... (bijv. 6712)' : 'Begin met typen... (bijv. 77)',
                  hintStyle: const TextStyle(color: AppTheme.border),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      _hideDropdown();
                      setState(() {
                        _result = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_result != null) ...[
                Card(
                  elevation: 4,
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.border, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: AppTheme.primary),
                                  ),
                                  child: const Center(
                                    child: Text('🐄', style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Resultaat',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: _toggleFavoriet,
                              icon: Icon(
                                _isFavoriet ? Icons.favorite : Icons.favorite_border,
                                color: _isFavoriet ? AppTheme.primary : AppTheme.textSecondary,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppTheme.border),
                        _buildInfoRow('Koe nummer:', _result!['koe']),
                        _buildInfoRow('Levensnummer:', _result!['levensnummer']),
                        _buildInfoRow('aAa:', _result!['triple']),
                        _buildInfoRow('Advies stier 1:', _result!['advies1'], kiCode: _result!['kiCode1']),
                        _buildInfoRow('Advies stier 2:', _result!['advies2'], kiCode: _result!['kiCode2']),
                        _buildInfoRow('Advies stier 3:', _result!['advies3'], kiCode: _result!['kiCode3']),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {String? kiCode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (kiCode != null && kiCode.isNotEmpty && kiCode != '-')
            TextButton.icon(
              onPressed: () => StierInfoDialog.show(context, kiCode, value),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Meer info'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppTheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== GESCHIEDENIS SCHERM ====================
class GeschiedenisScreen extends StatefulWidget {
  const GeschiedenisScreen({super.key});

  @override
  State<GeschiedenisScreen> createState() => _GeschiedenisScreenState();
}

class _GeschiedenisScreenState extends State<GeschiedenisScreen> {
  List<KoeAdvies> _geschiedenis = [];

  @override
  void initState() {
    super.initState();
    _loadGeschiedenis();
  }

  Future<void> _loadGeschiedenis() async {
    final geschiedenis = await StorageService.getGeschiedenis();
    setState(() {
      _geschiedenis = geschiedenis;
    });
  }

  Future<void> _clearGeschiedenis() async {
    await StorageService.clearGeschiedenis();
    _loadGeschiedenis();
  }

  void _nieuwXmlSelecteren() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const StartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: buildGGIAppBar(context, onNieuwXml: _nieuwXmlSelecteren),
      body: _geschiedenis.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: AppTheme.border),
                  const SizedBox(height: 16),
                  const Text('Nog geen geschiedenis', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _geschiedenis.length,
              itemBuilder: (context, index) {
                final item = _geschiedenis[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: const Icon(Icons.history, color: AppTheme.primary),
                    ),
                    title: Text(
                      'Koe: ${item.koe}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      'aAa: ${item.triple}\nDatum: ${item.zoekDatum.day}-${item.zoekDatum.month}-${item.zoekDatum.year}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: Text('Details Koe ${item.koe}', style: const TextStyle(color: AppTheme.textPrimary)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailText('Levensnummer:', item.levensnummer),
                              _buildDetailText('aAa:', item.triple),
                              _buildDetailText('Advies 1:', item.advies1, kiCode: item.kiCode1),
                              _buildDetailText('Advies 2:', item.advies2, kiCode: item.kiCode2),
                              _buildDetailText('Advies 3:', item.advies3, kiCode: item.kiCode3),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Sluiten', style: TextStyle(color: AppTheme.primary)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: _geschiedenis.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text('Geschiedenis wissen', style: TextStyle(color: AppTheme.textPrimary)),
                    content: const Text('Weet je zeker dat je alle zoekgeschiedenis wilt wissen?', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuleren', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearGeschiedenis();
                        },
                        child: const Text('Wissen', style: TextStyle(color: AppTheme.primary)),
                      ),
                    ],
                  ),
                );
              },
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
    );
  }

  Widget _buildDetailText(String label, String value, {String? kiCode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary)),
          ),
          if (kiCode != null && kiCode.isNotEmpty && kiCode != '-')
            TextButton(
              onPressed: () => StierInfoDialog.show(context, kiCode, value),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppTheme.primary,
              ),
              child: const Text('Info'),
            ),
        ],
      ),
    );
  }
}

// ==================== FAVORIETEN SCHERM ====================
class FavorietenScreen extends StatefulWidget {
  const FavorietenScreen({super.key});

  @override
  State<FavorietenScreen> createState() => _FavorietenScreenState();
}

class _FavorietenScreenState extends State<FavorietenScreen> {
  List<KoeAdvies> _favorieten = [];

  @override
  void initState() {
    super.initState();
    _loadFavorieten();
  }

  Future<void> _loadFavorieten() async {
    final favorieten = await StorageService.getFavorieten();
    setState(() {
      _favorieten = favorieten;
    });
  }

  Future<void> _removeFavoriet(KoeAdvies advies) async {
    await StorageService.toggleFavoriet(advies);
    _loadFavorieten();
  }

  void _nieuwXmlSelecteren() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const StartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: buildGGIAppBar(context, onNieuwXml: _nieuwXmlSelecteren),
      body: _favorieten.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: AppTheme.border),
                  const SizedBox(height: 16),
                  const Text('Nog geen favorieten', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favorieten.length,
              itemBuilder: (context, index) {
                final item = _favorieten[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: const Icon(Icons.favorite, color: AppTheme.primary),
                    ),
                    title: Text(
                      'Koe: ${item.koe}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      'aAa: ${item.triple}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.primary),
                      onPressed: () => _removeFavoriet(item),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: Text('Details Koe ${item.koe}', style: const TextStyle(color: AppTheme.textPrimary)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailText('Levensnummer:', item.levensnummer),
                              _buildDetailText('aAa:', item.triple),
                              _buildDetailText('Advies 1:', item.advies1, kiCode: item.kiCode1),
                              _buildDetailText('Advies 2:', item.advies2, kiCode: item.kiCode2),
                              _buildDetailText('Advies 3:', item.advies3, kiCode: item.kiCode3),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Sluiten', style: TextStyle(color: AppTheme.primary)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailText(String label, String value, {String? kiCode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary)),
          ),
          if (kiCode != null && kiCode.isNotEmpty && kiCode != '-')
            TextButton(
              onPressed: () => StierInfoDialog.show(context, kiCode, value),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppTheme.primary,
              ),
              child: const Text('Info'),
            ),
        ],
      ),
    );
  }
}

// ==================== STIER INFO DIALOG ====================
class StierInfoDialog extends StatefulWidget {
  final String kiCode;
  final String stierName;

  const StierInfoDialog({super.key, required this.kiCode, required this.stierName});

  static void show(BuildContext context, String kiCode, String stierName) {
    showDialog(
      context: context,
      builder: (context) => StierInfoDialog(kiCode: kiCode, stierName: stierName),
    );
  }

  @override
  State<StierInfoDialog> createState() => _StierInfoDialogState();
}

class _StierInfoDialogState extends State<StierInfoDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final code = widget.kiCode.replaceAll(' ', '');
      
      HttpClient client = HttpClient();
      client.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      
      HttpClientRequest request = await client.postUrl(Uri.parse('https://stierzoeken-api.cooperatie-crv.nl/indexes(\'bullinfo_apr2026_4\')/docs/search.post.search?api-version=2020-06-30'));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('api-key', 'none');
      request.headers.set('Accept', 'application/json');
      
      request.write(jsonEncode({
        "search": "$code*",
        "select": "fullName,milkKilograms,percentageFat,percentageProtein,lifeSpan,fertility,udder,legwork",
        "top": 1
      }));
      
      HttpClientResponse response = await request.close();
      
      if (response.statusCode == 200) {
        String reply = await response.transform(utf8.decoder).join();
        if (mounted) {
          setState(() {
            final parsed = json.decode(reply);
            if (parsed['value'] != null && parsed['value'].isNotEmpty) {
              _data = parsed['value'][0];
            } else {
              _data = {}; // No extra data found
            }
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kan stier gegevens niet laden.\nControleer uw internetverbinding.';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Fokwaarde stier: ${widget.stierName}', style: const TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            : _error != null
                ? Text(_error!, style: const TextStyle(color: AppTheme.primary))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRow('Naam', _data?['fullName'] ?? widget.stierName),
                        _buildRow('KI Code', widget.kiCode),
                        const Divider(color: AppTheme.border, height: 20),
                        const Text('Fokwaarden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                        const SizedBox(height: 8),
                        if (_data != null && _data!.isEmpty)
                          const Text('Geen verdere fokwaarden beschikbaar voor deze stier.', style: TextStyle(color: AppTheme.textSecondary))
                        else ...[
                          _buildRow('Melk (kg)', _data?['milkKilograms']),
                          _buildRow('Vet %', _data?['percentageFat']),
                          _buildRow('Eiwit %', _data?['percentageProtein']),
                          _buildRow('LVD (Levensduur)', _data?['lifeSpan']),
                          _buildRow('VRu (Vruchtbaarheid)', _data?['fertility']),
                          _buildRow('U (Uier)', _data?['udder']),
                          _buildRow('B (Beenwerk)', _data?['legwork']),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final code = widget.kiCode.replaceAll(' ', '');
            final url = Uri.parse('https://shop.crv4all.nl/nl/nld/bull/$code');
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kan website niet openen')));
              }
            }
          },
          child: const Text('Website CRV', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Sluiten', style: TextStyle(color: AppTheme.primary)),
        ),
      ],
    );
  }
}
