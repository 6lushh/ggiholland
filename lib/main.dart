import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
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
class LocatieConfig {
  final String id;
  final String ubn;
  final String bedrijfsnaam;
  final String alias;

  LocatieConfig({
    required this.id,
    required this.ubn,
    required this.bedrijfsnaam,
    required this.alias,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ubn': ubn,
    'bedrijfsnaam': bedrijfsnaam,
    'alias': alias,
  };

  factory LocatieConfig.fromJson(Map<String, dynamic> json) => LocatieConfig(
    id: json['id'],
    ubn: json['ubn'],
    bedrijfsnaam: json['bedrijfsnaam'],
    alias: json['alias'],
  );
}

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
  final String? locatieAlias;

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
    this.locatieAlias,
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
    'locatieAlias': locatieAlias,
  };

  factory KoeAdvies.fromJson(Map<String, dynamic> json) => KoeAdvies(
    koe: json['koe'],
    levensnummer: json['levensnummer'],
    triple: json['triple'],
    advies1: json['advies1'],
    advies2: json['advies2'],
    advies3: json['advies3'],
    kiCode1: json['kiCode1'],
    kiCode2: json['kiCode2'],
    kiCode3: json['kiCode3'],
    zoekDatum: DateTime.parse(json['zoekDatum']),
    locatieAlias: json['locatieAlias'],
  );
}

class StorageService {
  static const String _geschiedenisKey = 'zoek_geschiedenis';
  static const String _favorietenKey = 'favorieten';
  static const String _locatiesKey = 'opgeslagen_locaties';

  static Future<List<LocatieConfig>> getLocaties() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_locatiesKey);
    if (jsonList == null) return [];
    return jsonList
        .map((json) => LocatieConfig.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveLocaties(List<LocatieConfig> locaties) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = locaties.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_locatiesKey, jsonList);
  }

  static Future<void> addLocatie(LocatieConfig config) async {
    final locaties = await getLocaties();
    locaties.removeWhere((l) => l.id == config.id);
    locaties.add(config);
    await saveLocaties(locaties);
  }

  static Future<void> removeLocatie(String id) async {
    final locaties = await getLocaties();
    locaties.removeWhere((l) => l.id == id);
    await saveLocaties(locaties);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('xmlData_$id');
    await prefs.remove('xmlPad_$id');
  }

  static Future<void> saveXmlDataForLocatie(
    String id,
    List<Map<String, String>> xmlData,
    String bestandPad,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = xmlData.map((row) => jsonEncode(row)).toList();
    await prefs.setStringList('xmlData_$id', jsonList);
    await prefs.setString('xmlPad_$id', bestandPad);
  }

  static Future<List<Map<String, String>>?> getXmlDataForLocatie(
    String id,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('xmlData_$id');
    if (jsonList == null) return null;
    return jsonList
        .map((json) => Map<String, String>.from(jsonDecode(json)))
        .toList();
  }

  static Future<String?> getXmlPadForLocatie(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('xmlPad_$id');
  }

  static Future<List<Map<String, String>>> getAllCombinedXmlData() async {
    final locaties = await getLocaties();
    List<Map<String, String>> combined = [];

    for (var loc in locaties) {
      final data = await getXmlDataForLocatie(loc.id);
      if (data != null) {
        for (var row in data) {
          row['LocatieAlias'] = loc.alias;
          combined.add(row);
        }
      }
    }
    return combined;
  }

  static Future<List<KoeAdvies>> getGeschiedenis() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_geschiedenisKey);
    if (jsonList == null) return [];
    return jsonList
        .map((json) => KoeAdvies.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> clearGeschiedenis() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geschiedenisKey);
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

  static Future<List<KoeAdvies>> getFavorieten() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_favorietenKey);
    if (jsonList == null) return [];
    return jsonList
        .map((json) => KoeAdvies.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<bool> isFavoriet(String koeNummer) async {
    final favorieten = await getFavorieten();
    return favorieten.any((f) => f.koe == koeNummer);
  }

  static Future<void> toggleFavoriet(KoeAdvies advies) async {
    final prefs = await SharedPreferences.getInstance();
    List<KoeAdvies> favorieten = await getFavorieten();
    final isFav = favorieten.any((f) => f.koe == advies.koe);
    if (isFav) {
      favorieten.removeWhere((f) => f.koe == advies.koe);
    } else {
      favorieten.insert(0, advies);
    }
    final jsonList = favorieten.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_favorietenKey, jsonList);
  }
}

// ==================== SPLASH SCREEN ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Reset de v13_cleared flag om data te clearen
    _checkDataAndNavigate();
  }

  Future<void> _checkDataAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCleared = prefs.getBool('v15_cleared') ?? false;

    if (!hasCleared) {
      final locaties = await StorageService.getLocaties();
      for (var loc in locaties) {
        await StorageService.removeLocatie(loc.id);
      }
      await StorageService.clearGeschiedenis();
      await prefs.remove(StorageService._favorietenKey);
      await prefs.setBool('v15_cleared', true);
    }

    final opgeslagenXml = await StorageService.getAllCombinedXmlData();

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
          MaterialPageRoute(builder: (context) => const LocatiesScreen()),
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
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primary,
                      ),
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
class XmlFileInfo {
  final String fileName;
  final String lastModified;
  final DateTime parsedDate;

  XmlFileInfo(this.fileName, this.lastModified, this.parsedDate);
}

class LocatiesScreen extends StatefulWidget {
  const LocatiesScreen({super.key});

  @override
  State<LocatiesScreen> createState() => _LocatiesScreenState();
}

class _LocatiesScreenState extends State<LocatiesScreen> {
  List<LocatieConfig> _locaties = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocaties();
  }

  Future<void> _loadLocaties() async {
    final locs = await StorageService.getLocaties();
    setState(() {
      _locaties = locs;
    });
  }

  void _showAddLocatieDialog() {
    final ubnCtrl = TextEditingController();
    final bedrijfsnaamCtrl = TextEditingController();
    final aliasCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Nieuwe Locatie Toevoegen',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ubnCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'UBN Nummer',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            TextField(
              controller: bedrijfsnaamCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Bedrijfsnaam',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            TextField(
              controller: aliasCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Locatienaam',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuleren',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final u = ubnCtrl.text.trim();
              final b = bedrijfsnaamCtrl.text.trim();
              final a = aliasCtrl.text.trim();
              if (u.isEmpty || b.isEmpty || a.isEmpty) return;
              Navigator.pop(ctx);
              _addLocatie(u, b, a);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text(
              'Toevoegen',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addLocatie(
    String ubn,
    String bedrijfsnaam,
    String alias,
  ) async {
    setState(() => _isLoading = true);

    final folderName = "$ubn - $bedrijfsnaam";
    final dirUrl = Uri.parse('http://212.227.3.89/GGI/$folderName/');

    try {
      final response = await http
          .get(dirUrl, headers: {'X-GGI-App': 'True'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final htmlContent = response.body;
        final regex = RegExp(
          r'<a href="([^"]+\.xml)">.*?</a>.*?<td align="right">\s*([^<]+?)\s*</td>',
        );
        final matches = regex.allMatches(htmlContent);

        List<XmlFileInfo> files = [];
        for (var match in matches) {
          final fileName = match.group(1)!;
          final dateStr = match.group(2)!.trim();
          DateTime? parsedDate;
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            parsedDate = DateTime.fromMillisecondsSinceEpoch(0);
          }
          files.add(XmlFileInfo(fileName, dateStr, parsedDate));
        }

        if (files.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Geen XML bestanden gevonden voor deze locatie.'),
              ),
            );
          }
        } else {
          files.sort((a, b) => b.parsedDate.compareTo(a.parsedDate));
          if (mounted) {
            _showFileSelectionBottomSheet(
              context,
              ubn,
              bedrijfsnaam,
              alias,
              folderName,
              files,
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kan locatie niet vinden op de server. Controleer UBN en Bedrijfsnaam.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Netwerkfout: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFileSelectionBottomSheet(
    BuildContext context,
    String ubn,
    String bedrijfsnaam,
    String alias,
    String folderName,
    List<XmlFileInfo> files,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kies een XML bestand',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.insert_drive_file,
                        color: AppTheme.primary,
                      ),
                      title: Text(
                        file.fileName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Gewijzigd: ${file.lastModified}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _downloadSpecificFile(
                          ubn,
                          bedrijfsnaam,
                          alias,
                          folderName,
                          file.fileName,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadSpecificFile(
    String ubn,
    String bedrijfsnaam,
    String alias,
    String folderName,
    String fileName,
  ) async {
    setState(() => _isLoading = true);
    try {
      final fileUrl = Uri.parse(
        'http://212.227.3.89/GGI/$folderName/$fileName',
      );
      final fileResponse = await http
          .get(fileUrl, headers: {'X-GGI-App': 'True'})
          .timeout(const Duration(seconds: 15));

      if (fileResponse.statusCode == 200) {
        List<Map<String, String>> parsedData = [];
        final document = XmlDocument.parse(fileResponse.body);
        final cows = document.findAllElements('cows');

        for (var cow in cows) {
          String rawEarTag =
              cow.findElements('EarTag').firstOrNull?.innerText ?? '';
          String digitsOnly = rawEarTag.replaceAll(RegExp(r'\D'), '');
          String werknummer = digitsOnly.length >= 8
              ? digitsOnly.substring(4, 8)
              : digitsOnly;

          parsedData.add({
            'CowNumber':
                cow.findElements('CowNumber').firstOrNull?.innerText ?? '',
            'EarTag': rawEarTag,
            'Werknummer': werknummer,
            'Triple':
                cow.findElements('triple').firstOrNull?.innerText ??
                cow.findElements('Triple').firstOrNull?.innerText ??
                cow.findElements('TripleA').firstOrNull?.innerText ??
                '',
            'Sire': cow.findElements('Sire').firstOrNull?.innerText ?? '',
            'NameBull1':
                cow.findElements('NameBull1').firstOrNull?.innerText ?? '',
            'NameBull2':
                cow.findElements('NameBull2').firstOrNull?.innerText ?? '',
            'NameBull3':
                cow.findElements('NameBull3').firstOrNull?.innerText ?? '',
            'AICodeBull1':
                cow.findElements('AICodeBull1').firstOrNull?.innerText ?? '',
            'AICodeBull2':
                cow.findElements('AICodeBull2').firstOrNull?.innerText ?? '',
            'AICodeBull3':
                cow.findElements('AICodeBull3').firstOrNull?.innerText ?? '',
          });
        }

        final config = LocatieConfig(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          ubn: ubn,
          bedrijfsnaam: bedrijfsnaam,
          alias: alias,
        );

        await StorageService.addLocatie(config);
        await StorageService.saveXmlDataForLocatie(
          config.id,
          parsedData,
          'Server XML: $fileName',
        );

        await _loadLocaties();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Locatie $alias succesvol toegevoegd!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fout bij verwerken XML: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verwijderLocatie(String id) async {
    await StorageService.removeLocatie(id);
    await _loadLocaties();
  }

  void _gaNaarZoeken() async {
    final combinedData = await StorageService.getAllCombinedXmlData();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(xmlData: combinedData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Mijn Locaties',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.background,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
              children: [
                Expanded(
                  child: _locaties.isEmpty
                      ? const Center(
                          child: Text(
                            'Geen locaties gevonden.\nVoeg er een toe om te beginnen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _locaties.length,
                          itemBuilder: (context, index) {
                            final loc = _locaties[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color: AppTheme.surface,
                              child: ListTile(
                                title: Text(
                                  loc.alias,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${loc.ubn} - ${loc.bedrijfsnaam}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _verwijderLocatie(loc.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _showAddLocatieDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text(
                          'Locatie Toevoegen',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _locaties.isNotEmpty ? _gaNaarZoeken : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text(
                          'Ga naar Zoeken',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
  late List<Map<String, String>> _currentXmlData;

  @override
  void initState() {
    super.initState();
    _currentXmlData = widget.xmlData;
    _checkForUpdatesInBackground();
  }

  Future<void> _checkForUpdatesInBackground() async {
    try {
      final locaties = await StorageService.getLocaties();
      if (locaties.isEmpty) return;

      for (var loc in locaties) {
        final xmlPad = await StorageService.getXmlPadForLocatie(loc.id);
        if (xmlPad == null || !xmlPad.startsWith('Server XML: ')) continue;

        final folderName = "${loc.ubn} - ${loc.bedrijfsnaam}";
        final dirUrl = Uri.parse('http://212.227.3.89/GGI/$folderName/');
        final response = await http
            .get(dirUrl, headers: {'X-GGI-App': 'True'})
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) continue;

        final htmlContent = response.body;
        final regex = RegExp(
          r'<a href="([^"]+\.xml)">.*?</a>.*?<td align="right">\s*([^<]+?)\s*</td>',
        );
        final matches = regex.allMatches(htmlContent);

        List<XmlFileInfo> files = [];
        for (var match in matches) {
          final fileName = match.group(1)!;
          final dateStr = match.group(2)!.trim();
          DateTime? parsedDate;
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            parsedDate = DateTime.fromMillisecondsSinceEpoch(0);
          }
          files.add(XmlFileInfo(fileName, dateStr, parsedDate));
        }

        if (files.isEmpty) continue;
        files.sort((a, b) => b.parsedDate.compareTo(a.parsedDate));

        final newestFileName = files.first.fileName;
        if (xmlPad == 'Server XML: $newestFileName') continue;

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: AppTheme.surface,
                title: Text(
                  'Nieuw advies voor ${loc.alias}',
                  style: const TextStyle(color: Colors.white),
                ),
                content: Text(
                  'Er is een nieuwer bestand gevonden op de server ($newestFileName).\nWilt u deze nu inladen?',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Later',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _downloadAndUpdateXml(loc, newestFileName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text(
                      'Nu inladen',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _downloadAndUpdateXml(
    LocatieConfig loc,
    String newestFileName,
  ) async {
    try {
      final folderName = "${loc.ubn} - ${loc.bedrijfsnaam}";
      final fileUrl = Uri.parse(
        'http://212.227.3.89/GGI/$folderName/$newestFileName',
      );
      final fileResponse = await http
          .get(fileUrl, headers: {'X-GGI-App': 'True'})
          .timeout(const Duration(seconds: 15));
      if (fileResponse.statusCode != 200) return;

      List<Map<String, String>> parsedData = [];
      final document = XmlDocument.parse(fileResponse.body);
      final cows = document.findAllElements('cows');
      for (var cow in cows) {
        String rawEarTag =
            cow.findElements('EarTag').firstOrNull?.innerText ?? '';
        String digitsOnly = rawEarTag.replaceAll(RegExp(r'\D'), '');
        String werknummer = digitsOnly.length >= 8
            ? digitsOnly.substring(4, 8)
            : digitsOnly;
        parsedData.add({
          'CowNumber':
              cow.findElements('CowNumber').firstOrNull?.innerText ?? '',
          'EarTag': rawEarTag,
          'Werknummer': werknummer,
          'Triple':
              cow.findElements('triple').firstOrNull?.innerText ??
              cow.findElements('Triple').firstOrNull?.innerText ??
              cow.findElements('TripleA').firstOrNull?.innerText ??
              '',
          'Sire': cow.findElements('Sire').firstOrNull?.innerText ?? '',
          'NameBull1':
              cow.findElements('NameBull1').firstOrNull?.innerText ?? '',
          'NameBull2':
              cow.findElements('NameBull2').firstOrNull?.innerText ?? '',
          'NameBull3':
              cow.findElements('NameBull3').firstOrNull?.innerText ?? '',
          'AICodeBull1':
              cow.findElements('AICodeBull1').firstOrNull?.innerText ?? '',
          'AICodeBull2':
              cow.findElements('AICodeBull2').firstOrNull?.innerText ?? '',
          'AICodeBull3':
              cow.findElements('AICodeBull3').firstOrNull?.innerText ?? '',
        });
      }

      await StorageService.saveXmlDataForLocatie(
        loc.id,
        parsedData,
        'Server XML: $newestFileName',
      );
      final combined = await StorageService.getAllCombinedXmlData();
      if (mounted) {
        setState(() {
          _currentXmlData = combined;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nieuw XML bestand voor ${loc.alias} succesvol ingeladen!',
            ),
          ),
        );
      }
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          SearchScreen(xmlData: _currentXmlData),
          _currentIndex == 1
              ? const GeschiedenisScreen()
              : const SizedBox.shrink(),
          _currentIndex == 2
              ? const FavorietenScreen()
              : const SizedBox.shrink(),
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
AppBar buildGGIAppBar(
  BuildContext context, {
  required VoidCallback onNieuwXml,
}) {
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
  void _onSearchChanged(String query) {
    _hideDropdown();

    if (query.isEmpty) {
      setState(() {
        _result = null;
      });
      return;
    }

    final matches = widget.xmlData.where((cow) {
      final cowNum = cow['CowNumber'] ?? '';
      final werkNum = cow['Werknummer'] ?? '';
      return cowNum.contains(query) || werkNum.contains(query);
    }).toList();

    // Sorteer zodat Halsband (CowNumber) eerst komt
    matches.sort((a, b) {
      final aCow = (a['CowNumber'] ?? '').contains(query);
      final bCow = (b['CowNumber'] ?? '').contains(query);
      if (aCow && !bCow) return -1;
      if (!aCow && bCow) return 1;
      return 0;
    });

    final topMatches = matches.take(5).toList();

    if (topMatches.isNotEmpty) {
      _showDropdown(topMatches);
    }
  }

  void _showDropdown(List<Map<String, String>> matches) {
    if (!mounted) return;
    _hideDropdown();

    final RenderBox renderBox =
        _searchFieldKey.currentContext!.findRenderObject() as RenderBox;
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
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, index) {
                final match = matches[index];
                final cowNum = match['CowNumber'] ?? '';
                final werkNum = match['Werknummer'] ?? '';
                final titleText = cowNum.isNotEmpty && werkNum.isNotEmpty
                    ? '$cowNum - $werkNum'
                    : '$cowNum$werkNum';

                return ListTile(
                  title: Text(
                    titleText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'aAa: ${match['Triple'] ?? "Onbekend"}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  onTap: () {
                    _hideDropdown();
                    _searchController.text = match['CowNumber'] ?? '';
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
      locatieAlias: cow['LocatieAlias'],
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
      MaterialPageRoute(builder: (context) => const LocatiesScreen()),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;

              final searchControls = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: _searchFieldKey,
                    controller: _searchController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Diernummer',
                      labelStyle: const TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                      hintText: 'Begin met typen... (bijv. 77)',
                      hintStyle: const TextStyle(color: AppTheme.border),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.primary,
                      ),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppTheme.textSecondary,
                        ),
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
                ],
              ); // End of searchControls

              final resultCard = _result == null
                  ? null
                  : Card(
                      elevation: 4,
                      color: AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: AppTheme.border,
                          width: 1,
                        ),
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
                                        color: AppTheme.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '🐄',
                                          style: TextStyle(fontSize: 24),
                                        ),
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
                                    _isFavoriet
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _isFavoriet
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: AppTheme.border),
                            _buildInfoRow(
                              'Locatie:',
                              _result!['locatieAlias'] ?? 'Onbekend',
                            ),
                            _buildInfoRow('aAa:', _result!['triple']),
                            _buildInfoRow(
                              'Levensnummer:',
                              _result!['levensnummer'],
                            ),
                            _buildInfoRow(
                              'Stier 1:',
                              _result!['advies1'],
                              kiCode: _result!['kiCode1'],
                            ),
                            if (_result!['kiCode1'] != null &&
                                _result!['kiCode1'].toString().isNotEmpty)
                              _buildInfoRow(
                                'aAa stier 1:',
                                _result!['kiCode1'],
                              ),
                            _buildInfoRow(
                              'Stier 2:',
                              _result!['advies2'],
                              kiCode: _result!['kiCode2'],
                            ),
                            if (_result!['kiCode2'] != null &&
                                _result!['kiCode2'].toString().isNotEmpty)
                              _buildInfoRow(
                                'aAa stier 2:',
                                _result!['kiCode2'],
                              ),
                            _buildInfoRow(
                              'Stier 3:',
                              _result!['advies3'],
                              kiCode: _result!['kiCode3'],
                            ),
                            if (_result!['kiCode3'] != null &&
                                _result!['kiCode3'].toString().isNotEmpty)
                              _buildInfoRow(
                                'aAa stier 3:',
                                _result!['kiCode3'],
                              ),
                          ],
                        ),
                      ),
                    );

              if (isTablet) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: searchControls),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 1,
                      child: resultCard == null
                          ? const Center(
                              child: Text(
                                'Zoek en selecteer een koe om hier de resultaten te zien.',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            )
                          : SingleChildScrollView(child: resultCard),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchControls,
                  const SizedBox(height: 20),
                  if (resultCard != null)
                    Expanded(child: SingleChildScrollView(child: resultCard)),
                ],
              );
            },
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
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (kiCode != null && kiCode.isNotEmpty && kiCode != '-')
                  TextButton.icon(
                    onPressed: () =>
                        StierInfoDialog.show(context, kiCode, value),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Info'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
              ],
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
      MaterialPageRoute(builder: (context) => const LocatiesScreen()),
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
                  const Text(
                    'Nog geen geschiedenis',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 500,
                mainAxisExtent: 120,
                crossAxisSpacing: 16,
                mainAxisSpacing: 12,
              ),
              itemCount: _geschiedenis.length,
              itemBuilder: (context, index) {
                final item = _geschiedenis[index];
                return Card(
                  margin: EdgeInsets.zero,
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: const Icon(Icons.history, color: AppTheme.primary),
                    ),
                    title: Text(
                      'Koe: ${item.koe}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Locatie: ${item.locatieAlias ?? "Onbekend"}\naAa: ${item.triple}\nDatum: ${item.zoekDatum.day}-${item.zoekDatum.month}-${item.zoekDatum.year}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondary,
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: Text(
                            'Details Koe ${item.koe}',
                            style: const TextStyle(color: AppTheme.textPrimary),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailText(
                                'Locatie',
                                item.locatieAlias ?? 'Onbekend',
                              ),
                              _buildDetailText(
                                'Levensnummer:',
                                item.levensnummer,
                              ),
                              _buildDetailText('aAa:', item.triple),
                              _buildDetailText(
                                'Advies 1:',
                                item.advies1,
                                kiCode: item.kiCode1,
                              ),
                              _buildDetailText(
                                'Advies 2:',
                                item.advies2,
                                kiCode: item.kiCode2,
                              ),
                              _buildDetailText(
                                'Advies 3:',
                                item.advies3,
                                kiCode: item.kiCode3,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Sluiten',
                                style: TextStyle(color: AppTheme.primary),
                              ),
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
                    title: const Text(
                      'Geschiedenis wissen',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    content: const Text(
                      'Weet je zeker dat je alle zoekgeschiedenis wilt wissen?',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Annuleren',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearGeschiedenis();
                        },
                        child: const Text(
                          'Wissen',
                          style: TextStyle(color: AppTheme.primary),
                        ),
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
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
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
      MaterialPageRoute(builder: (context) => const LocatiesScreen()),
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
                  const Text(
                    'Nog geen favorieten',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 500,
                mainAxisExtent: 120,
                crossAxisSpacing: 16,
                mainAxisSpacing: 12,
              ),
              itemCount: _favorieten.length,
              itemBuilder: (context, index) {
                final item = _favorieten[index];
                return Card(
                  margin: EdgeInsets.zero,
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.favorite,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      'Koe: ${item.koe}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Locatie: ${item.locatieAlias ?? "Onbekend"}\naAa: ${item.triple}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.primary,
                      ),
                      onPressed: () => _removeFavoriet(item),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: Text(
                            'Details Koe ${item.koe}',
                            style: const TextStyle(color: AppTheme.textPrimary),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailText(
                                'Locatie',
                                item.locatieAlias ?? 'Onbekend',
                              ),
                              _buildDetailText(
                                'Levensnummer:',
                                item.levensnummer,
                              ),
                              _buildDetailText('aAa:', item.triple),
                              _buildDetailText(
                                'Advies 1:',
                                item.advies1,
                                kiCode: item.kiCode1,
                              ),
                              _buildDetailText(
                                'Advies 2:',
                                item.advies2,
                                kiCode: item.kiCode2,
                              ),
                              _buildDetailText(
                                'Advies 3:',
                                item.advies3,
                                kiCode: item.kiCode3,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Sluiten',
                                style: TextStyle(color: AppTheme.primary),
                              ),
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
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
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

  const StierInfoDialog({
    super.key,
    required this.kiCode,
    required this.stierName,
  });

  static void show(BuildContext context, String kiCode, String stierName) {
    showDialog(
      context: context,
      builder: (context) =>
          StierInfoDialog(kiCode: kiCode, stierName: stierName),
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
      client.badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);

      HttpClientRequest request = await client.postUrl(
        Uri.parse(
          'https://stierzoeken-api.cooperatie-crv.nl/indexes(\'bullinfo_apr2026_4\')/docs/search.post.search?api-version=2020-06-30',
        ),
      );
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('api-key', 'none');
      request.headers.set('Accept', 'application/json');

      request.write(
        jsonEncode({
          "search": "$code*",
          "select":
              "fullName,milkKilograms,percentageFat,percentageProtein,lifeSpan,fertility,udder,legwork",
          "top": 1,
        }),
      );

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
          _error =
              'Kan stier gegevens niet laden.\nControleer uw internetverbinding.';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty)
      return const SizedBox.shrink();

    String valStr = value.toString();
    if (valStr.endsWith('.0')) {
      valStr = valStr.substring(0, valStr.length - 2);
    }

    if ((label == 'Vet %' || label == 'Eiwit %') &&
        valStr.isNotEmpty &&
        !valStr.startsWith('-') &&
        valStr != '0') {
      valStr = '+$valStr';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            valStr,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(
        'Fokwaarde stier: ${widget.stierName}',
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
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
                    const Text(
                      'Fokwaarden',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_data != null && _data!.isEmpty)
                      const Text(
                        'Geen verdere fokwaarden beschikbaar voor deze stier.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      )
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
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Sluiten',
            style: TextStyle(color: AppTheme.primary),
          ),
        ),
      ],
    );
  }
}
