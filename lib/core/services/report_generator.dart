import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportGenerator {
  static Future<void> generateAndPrintReport(Map<dynamic, dynamic> hazardData) async {
    final pdf = pw.Document();

    // Optional: Load GMI Logo if you have it in assets, otherwise omit/comment out
    pw.MemoryImage? gmiLogo;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/gmi_logo.png');
      gmiLogo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // Logo asset not found yet, will render text-only header
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header with Logo (if available)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (gmiLogo != null)
                  pw.Image(gmiLogo, width: 100, height: 200)
                else
                  pw.Text('GMI', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'German-Malaysian Institute (GMI)',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Facilities Maintenance & Asset Management Section',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 10),

            // Document Title
            pw.Text(
              'Facilities Maintenance & Asset Management Report',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
            ),
            pw.SizedBox(height: 15),

            // Section 1: Facilities Maintenance Section
            pw.Text('1. Facilities Maintenance Section', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Maintenance Unit: Campus Infrastructure & Road Safety Maintenance'),
            pw.Bullet(text: 'Inspection Scope: Campus Roadways, Walkways, and Drainage Zones'),
            pw.Bullet(text: 'Report Status: ${hazardData['status'] ?? 'Pending'}'),
            pw.SizedBox(height: 10),

            // Section 2: Assets & Facilities Management Section
            pw.Text('2. Assets & Facilities Management Section', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Asset ID / Node: ${hazardData['device_id'] ?? 'GMI_IOT_NODE_01'}'),
            pw.Bullet(text: 'Location Name: ${hazardData['location_name'] ?? hazardData['location'] ?? 'Unknown'}'),
            pw.Bullet(text: 'Severity Level: ${(hazardData['severity'] ?? 'N/A').toString().toUpperCase()}'),
            pw.SizedBox(height: 10),

            // Section 3: Incident Summary & Metrics from DB
            pw.Text('3. Incident Summary & Metrics', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'Priority Score: ${hazardData['priority_score'] ?? hazardData['priority'] ?? 0} / 100'),
            pw.Bullet(text: 'Dimensions: Depth ${hazardData['depth_cm'] ?? hazardData['depth'] ?? 0} cm | Width ${hazardData['width_cm'] ?? hazardData['width'] ?? 0} cm'),
            pw.Bullet(text: 'Impact Vibration: ${hazardData['vibration_g'] ?? hazardData['vibration'] ?? 0} G'),
          ];
        },
      ),
    );

    // Open native print/preview export dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}