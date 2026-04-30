import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGI Holland - Stieradvies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}

// ==================== DATA MODELS ====================
class KoeAdvies {
  final String koe;
  final String triple;
  final String advies1;
  final String advies2;
  final String advies3;
  final DateTime zoekDatum;

  KoeAdvies({
    required this.koe,
    required this.triple,
    required this.advies1,
    required this.advies2,
    required this.advies3,
    required this.zoekDatum,
  });

  Map<String, dynamic> toJson() => {
        'koe': koe,
        'triple': triple,
        'advies1': advies1,
        'advies2': advies2,
        'advies3': advies3,
        'zoekDatum': zoekDatum.toIso8601String(),
      };

  factory KoeAdvies.fromJson(Map<String, dynamic> json) => KoeAdvies(
        koe: json['koe'],
        triple: json['triple'],
        advies1: json['advies1'],
        advies2: json['advies2'],
        advies3: json['advies3'],
        zoekDatum: DateTime.parse(json['zoekDatum']),
      );
}

// ==================== STORAGE SERVICE ====================
class StorageService {
  static const String _geschiedenisKey = 'zoek_geschiedenis';
  static const String _favorietenKey = 'favorieten';

  static Future<void> saveZoekopdracht(KoeAdvies advies) async {
    final prefs = await SharedPreferences.getInstance();
    List<KoeAdvies> geschiedenis = await getGeschiedenis();
    
    // Voeg toe aan begin, verwijder duplicate
    geschiedenis.removeWhere((g) => g.koe == advies.koe);
    geschiedenis.insert(0, advies);
    
    // Max 50 items
    if (geschiedenis.length > 50) {
      geschiedenis = geschiedenis.sublist(0, 50);
    }
    
    final jsonList = geschiedenis.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_geschiedenisKey, jsonList);
  }

  static Future<List<KoeAdvies>> getGeschiedenis() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_geschiedenisKey) ?? [];
    return jsonList
        .map((json) => KoeAdvies.fromJson(jsonDecode(json)))
        .toList();
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
    return jsonList
        .map((json) => KoeAdvies.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<bool> isFavoriet(String koeNummer) async {
    final favorieten = await getFavorieten();
    return favorieten.any((f) => f.koe == koeNummer);
  }
}

// ==================== STARTSCHERM ====================
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  Future<void> _pickCsvFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String csvString = await file.readAsString();
      
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ';',
      ).convert(csvString);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(csvData: csvTable),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GGI Holland'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.agriculture,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 30),
              const Text(
                'Stieradvies App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Selecteer een CSV-bestand om te beginnen',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _pickCsvFile(context),
                icon: const Icon(Icons.upload_file, size: 28),
                label: const Text(
                  'CSV-bestand selecteren',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== MAIN SCREEN MET TABS ====================
class MainScreen extends StatefulWidget {
  final List<List<dynamic>> csvData;

  const MainScreen({super.key, required this.csvData});

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
          SearchScreen(csvData: widget.csvData),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Zoeken',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Geschiedenis',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite),
            label: 'Favorieten',
          ),
        ],
      ),
    );
  }
}

// ==================== ZOEKSCHERM ====================
class SearchScreen extends StatefulWidget {
  final List<List<dynamic>> csvData;

  const SearchScreen({super.key, required this.csvData});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _result;
  bool _isFavoriet = false;

  Future<void> _searchKoe() async {
    String searchNumber = _searchController.text.trim();
    
    for (int i = 1; i < widget.csvData.length; i++) {
      var row = widget.csvData[i];
      if (row.isNotEmpty && row[0].toString() == searchNumber) {
        final advies = KoeAdvies(
          koe: row[0].toString(),
          triple: row[1].toString(),
          advies1: row[2].toString(),
          advies2: row.length > 3 ? row[3].toString() : '-',
          advies3: row.length > 4 ? row[4].toString() : '-',
          zoekDatum: DateTime.now(),
        );

        await StorageService.saveZoekopdracht(advies);
        final isFav = await StorageService.isFavoriet(advies.koe);

        if (mounted) {
          setState(() {
            _result = {
              'koe': advies.koe,
              'triple': advies.triple,
              'advies1': advies.advies1,
              'advies2': advies.advies2,
              'advies3': advies.advies3,
            };
            _isFavoriet = isFav;
          });
        }
        return;
      }
    }
    
    setState(() {
      _result = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koe $searchNumber niet gevonden'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleFavoriet() async {
    if (_result == null) return;
    
    final advies = KoeAdvies(
      koe: _result!['koe'],
      triple: _result!['triple'],
      advies1: _result!['advies1'],
      advies2: _result!['advies2'],
      advies3: _result!['advies3'],
      zoekDatum: DateTime.now(),
    );

    await StorageService.toggleFavoriet(advies);
    final isFav = await StorageService.isFavoriet(advies.koe);

    setState(() {
      _isFavoriet = isFav;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFav ? 'Toegevoegd aan favorieten' : 'Verwijderd uit favorieten',
          ),
          backgroundColor: isFav ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zoek koe'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Koe nummer',
                hintText: 'Bijv. 6949',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _result = null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _searchKoe,
                icon: const Icon(Icons.search),
                label: const Text(
                  'Zoeken',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (_result != null) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Resultaat',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleFavoriet,
                            icon: Icon(
                              _isFavoriet
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: _isFavoriet ? Colors.red : Colors.grey,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildInfoRow('Koe nummer:', _result!['koe']),
                      _buildInfoRow('Triple:', _result!['triple']),
                      _buildInfoRow('Advies stier 1:', _result!['advies1']),
                      _buildInfoRow('Advies stier 2:', _result!['advies2']),
                      _buildInfoRow('Advies stier 3:', _result!['advies3']),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zoekgeschiedenis'),
        backgroundColor: Colors.green,
        actions: [
          if (_geschiedenis.isNotEmpty)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Geschiedenis wissen?'),
                    content: const Text(
                      'Alle zoekopdrachten worden verwijderd.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuleren'),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearGeschiedenis();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Wissen',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
      body: _geschiedenis.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Geen zoekgeschiedenis',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _geschiedenis.length,
              itemBuilder: (context, index) {
                final item = _geschiedenis[index];
                return ListTile(
                  leading: const Icon(Icons.search, color: Colors.green),
                  title: Text('Koe ${item.koe}'),
                  subtitle: Text(
                    '${item.triple} • ${_formatDatum(item.zoekDatum)}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Toon details in dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Koe ${item.koe}'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailText('Triple:', item.triple),
                            _buildDetailText('Advies 1:', item.advies1),
                            _buildDetailText('Advies 2:', item.advies2),
                            _buildDetailText('Advies 3:', item.advies3),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Sluiten'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildDetailText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 16),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _formatDatum(DateTime datum) {
    return '${datum.day}-${datum.month}-${datum.year} ${datum.hour}:${datum.minute.toString().padLeft(2, '0')}';
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

  Future<void> _removeFavoriet(String koeNummer) async {
    final advies = _favorieten.firstWhere((f) => f.koe == koeNummer);
    await StorageService.toggleFavoriet(advies);
    _loadFavorieten();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorieten'),
        backgroundColor: Colors.green,
      ),
      body: _favorieten.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'Geen favorieten',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Zoek een koe en tik op het hartje',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _favorieten.length,
              itemBuilder: (context, index) {
                final item = _favorieten[index];
                return Dismissible(
                  key: Key(item.koe),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _removeFavoriet(item.koe),
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text('Koe ${item.koe}'),
                    subtitle: Text(item.triple),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeFavoriet(item.koe),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Koe ${item.koe}'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailText('Triple:', item.triple),
                              _buildDetailText('Advies 1:', item.advies1),
                              _buildDetailText('Advies 2:', item.advies2),
                              _buildDetailText('Advies 3:', item.advies3),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Sluiten'),
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

  Widget _buildDetailText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 16),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}