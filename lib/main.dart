import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
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
      
      // CSV parsen
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ';',
      ).convert(csvString);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchScreen(csvData: csvTable),
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

  void _searchKoe() {
    String searchNumber = _searchController.text.trim();
    
    // Header overslaan (rij 0), zoeken vanaf rij 1
    for (int i = 1; i < widget.csvData.length; i++) {
      var row = widget.csvData[i];
      if (row.isNotEmpty && row[0].toString() == searchNumber) {
        setState(() {
          _result = {
            'koe': row[0],
            'triple': row[1],
            'advies1': row[2],
            'advies2': row.length > 3 ? row[3] : '-',
            'advies3': row.length > 4 ? row[4] : '-',
          };
        });
        return;
      }
    }
    
    // Niet gevonden
    setState(() {
      _result = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Koe $searchNumber niet gevonden'),
        backgroundColor: Colors.red,
      ),
    );
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
            // Zoekveld
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
                  onPressed: () => _searchController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Zoekknop
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
            
            // Resultaat
            if (_result != null) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Koe nummer:', _result!['koe'].toString()),
                      const Divider(),
                      _buildInfoRow('Triple:', _result!['triple'].toString()),
                      const Divider(),
                      _buildInfoRow('Advies stier 1:', _result!['advies1'].toString()),
                      const Divider(),
                      _buildInfoRow('Advies stier 2:', _result!['advies2'].toString()),
                      const Divider(),
                      _buildInfoRow('Advies stier 3:', _result!['advies3'].toString()),
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