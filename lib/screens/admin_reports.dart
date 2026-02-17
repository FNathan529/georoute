import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import '../services/supabase_service.dart'; // Make sure this path is correct

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  late SupabaseService _service;

  Map<String, dynamic> _summaryStats = {};
  List<Map<String, dynamic>> _categoryStats = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = SupabaseService();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _service.getReportStats();
      final categories = await _service.getCategoryStats();

      if (!mounted) return;

      setState(() {
        _summaryStats = stats;
        _categoryStats = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading report data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────
  //  GENERATE REPORT BYTES – NOW WITH REAL DATA
  // ────────────────────────────────────────────────
  Future<Uint8List> _generateReportBytes(String format) async {
    final timestamp = DateTime.now().toString();

    if (format == 'Excel') {
      var excel = Excel.createExcel();
      Sheet sheet = excel['GeoRoute Report'];
      excel.setDefaultSheet('GeoRoute Report');

      sheet.appendRow([TextCellValue('GeoRoute Analytics Report')]);
      sheet.appendRow([TextCellValue('Generated: $timestamp')]);
      sheet.appendRow([TextCellValue('')]);

      // Summary
      sheet.appendRow([TextCellValue('SUMMARY STATISTICS')]);
      sheet.appendRow([
        TextCellValue('Metric'),
        TextCellValue('Value'),
        TextCellValue('Details')
      ]);

      sheet.appendRow([
        TextCellValue('Total Destinations'),
        IntCellValue(_summaryStats['total_destinations'] ?? 0),
        TextCellValue('${_summaryStats['active_destinations'] ?? 0} active'),
      ]);
      sheet.appendRow([
        TextCellValue('Total Users'),
        IntCellValue(_summaryStats['total_users'] ?? 0),
        TextCellValue('${_summaryStats['pending_users'] ?? 0} pending'),
      ]);
      sheet.appendRow([
        TextCellValue('Average Rating'),
        TextCellValue(_summaryStats['avg_rating'] ?? '0.0'),
        TextCellValue('Across all destinations'),
      ]);
      sheet.appendRow([
        TextCellValue('Monthly Visits'),
        TextCellValue(_summaryStats['monthly_visits'] ?? 'N/A'),
        TextCellValue(''),
      ]);

      sheet.appendRow([TextCellValue('')]);

      // Categories
      sheet.appendRow([TextCellValue('CATEGORY STATISTICS')]);
      sheet.appendRow([
        TextCellValue('Category'),
        TextCellValue('Destinations'),
        TextCellValue('Avg Rating')
      ]);

      for (var stat in _categoryStats.skip(1)) {
        sheet.appendRow([
          TextCellValue(stat['category'].toString()),
          IntCellValue(stat['destinations'] ?? 0),
          TextCellValue(stat['rating'].toString()),
        ]);
      }

      var fileBytes = excel.save();
      return Uint8List.fromList(fileBytes!);
    } else {
      // PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'GeoRoute Analytics Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text('Generated: $timestamp'),
                pw.SizedBox(height: 20),
                pw.Text(
                  'SUMMARY STATISTICS',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                pw.Bullet(
                  text:
                      'Total Destinations: ${_summaryStats['total_destinations'] ?? 0} (${_summaryStats['active_destinations'] ?? 0} active)',
                ),
                pw.Bullet(
                  text:
                      'Total Users: ${_summaryStats['total_users'] ?? 0} (${_summaryStats['pending_users'] ?? 0} pending)',
                ),
                pw.Bullet(
                  text:
                      'Average Rating: ${_summaryStats['avg_rating'] ?? '0.0'}',
                ),
                pw.Bullet(
                  text:
                      'Monthly Visits: ${_summaryStats['monthly_visits'] ?? 'N/A'}',
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'CATEGORY STATISTICS',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                pw.Table.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    ['Category', 'Destinations', 'Avg Rating'],
                    ..._categoryStats.skip(1).map((item) => [
                          item['category'].toString(),
                          item['destinations'].toString(),
                          item['rating'].toString(),
                        ]),
                  ],
                ),
              ],
            );
          },
        ),
      );
      return await pdf.save();
    }
  }

  // ────────────────────────────────────────────────
  //  EXPORT FUNCTION
  // ────────────────────────────────────────────────
  Future<void> _performExport(String format, BuildContext ctx) async {
    try {
      Navigator.pop(ctx);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Downloading $format...'),
            duration: const Duration(seconds: 2)),
      );

      Uint8List fileBytes = await _generateReportBytes(format);

      MimeType mimeType =
          format == 'Excel' ? MimeType.microsoftExcel : MimeType.pdf;
      String ext = format == 'Excel' ? 'xlsx' : 'pdf';
      String name = 'GeoRoute_Report_${DateTime.now().millisecondsSinceEpoch}';

      await FileSaver.instance.saveFile(
        name: name,
        bytes: fileBytes,
        ext: ext,
        mimeType: mimeType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Download started!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSideNavigationBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _buildSummaryCards(),
                    const SizedBox(height: 30),
                    _buildCategoryStats(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  UI WIDGETS – USING REAL DATA
  // ────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final cards = [
      {
        'title': 'Total Destinations',
        'value': '${_summaryStats['total_destinations'] ?? 0}',
        'subtitle': '${_summaryStats['active_destinations'] ?? 0} active',
        'icon': Icons.location_on_outlined,
      },
      {
        'title': 'Total Users',
        'value': '${_summaryStats['total_users'] ?? 0}',
        'subtitle': '${_summaryStats['pending_users'] ?? 0} pending',
        'icon': Icons.people_outline,
      },
      {
        'title': 'Avg Rating',
        'value': _summaryStats['avg_rating'] ?? '0.0',
        'subtitle': 'Across all destinations',
        'icon': Icons.trending_up,
      },
      {
        'title': 'Monthly Visits',
        'value': _summaryStats['monthly_visits'] ?? 'N/A',
        'subtitle': 'This month',
        'icon': Icons.remove_red_eye_outlined,
      },
    ];

    return Row(
      children: cards.map((data) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'], style: const TextStyle(color: Colors.grey)),
                Text(
                  data['value'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2559),
                  ),
                ),
                Text(data['subtitle'], style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryStats() {
    if (_categoryStats.isEmpty || _categoryStats.length <= 1) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'No category data available yet',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ..._categoryStats.map((stat) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      stat['category'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(stat['destinations'].toString()),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(stat['rating'].toString()),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  SIDEBAR, HEADER, DIALOG – unchanged from your code
  // ────────────────────────────────────────────────

  Widget _buildSideNavigationBar(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF111C44),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GeoRoute Admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Admin User',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 50),
          _buildSideNavItem(
              context, Icons.grid_view, 'Dashboard', '/AdminDashboard', false),
          _buildSideNavItem(context, Icons.place, 'Destinations',
              '/AdminDestinations', false),
          _buildSideNavItem(
              context, Icons.category, 'Categories', '/AdminCategories', false),
          _buildSideNavItem(
              context, Icons.people, 'Users', '/AdminUsers', false),
          _buildSideNavItem(
              context, Icons.description, 'Reports', '/AdminReports', true),
          const Spacer(),
          _buildSideNavItem(context, Icons.logout, 'Logout', '/', false,
              isLogout: true),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(BuildContext context, IconData icon, String title,
      String routeName, bool isSelected,
      {bool isLogout = false}) {
    return GestureDetector(
      onTap: () {
        if (isLogout) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/onboarding', (route) => false);
        } else if (!isSelected) {
          Navigator.pushReplacementNamed(context, routeName);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.white70, size: 20),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Reports',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2559))),
        ElevatedButton.icon(
          onPressed: () => _showExportDialog(),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Export Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Report',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              _buildExportOption(ctx, Icons.picture_as_pdf, 'Export as PDF',
                  () => _performExport('PDF', ctx)),
              const SizedBox(height: 12),
              _buildExportOption(ctx, Icons.description, 'Export as Excel',
                  () => _performExport('Excel', ctx)),
              const SizedBox(height: 24),
              Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportOption(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ]),
      ),
    );
  }
}
