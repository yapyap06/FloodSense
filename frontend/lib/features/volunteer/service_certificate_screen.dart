import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../../core/utils/pdf_download_helper.dart' if (dart.library.html) '../../core/utils/pdf_download_helper_web.dart';
import '../../core/providers/locale_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/widgets/loc_text.dart';

/// Digital Service Certificate — shown after a mission is marked COMPLETED.
/// Acts as a verifiable record of volunteer service.
class ServiceCertificateScreen extends StatefulWidget {
  final String missionId;
  final Map<String, dynamic> data;
  const ServiceCertificateScreen({super.key, required this.missionId, required this.data});

  @override
  State<ServiceCertificateScreen> createState() => _ServiceCertificateScreenState();
}

class _ServiceCertificateScreenState extends State<ServiceCertificateScreen> {
  bool _isDownloading = false;

  Future<void> _downloadPDF(String certId, String name, String sosId, String dateStr, bool isMs) async {
    setState(() => _isDownloading = true);
    try {
      final pdfBytes = await _buildPdfBytes(certId, name, sosId, dateStr, isMs);

      if (kIsWeb || identical(0, 0.0)) {
        // Web: trigger browser file download via anchor blob
        downloadPdfWeb(pdfBytes, '$certId.pdf');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMs ? 'Sijil PDF berjaya dimuat turun!' : 'PDF certificate downloaded!',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return; // Early exit for Web
      } else {
        // Mobile: save to documents directory
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$certId.pdf');
        await file.writeAsBytes(pdfBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isMs ? "Dijimpan di" : "Saved to"}: ${file.path}',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isMs ? "Gagal memuat turun" : "Download failed"}: $e',
              style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Builds and returns the raw PDF bytes for this certificate.
  Future<List<int>> _buildPdfBytes(String certId, String name, String sosId, String dateStr, bool isMs) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(isMs ? 'SIJIL PERKHIDMATAN' : 'SERVICE CERTIFICATE',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                pw.SizedBox(height: 30),
                pw.Text(isMs ? 'Ini mengesahkan bahawa:' : 'This certifies that:',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                pw.SizedBox(height: 10),
                pw.Text(name, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(isMs ? 'telah berjaya menyempurnakan misi menyelamat banjir'
                    : 'has successfully completed a flood rescue mission',
                    style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: PdfColors.green100,
                  child: pw.Text((isMs ? 'Misi ' : 'Mission ') + sosId,
                      style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 40),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text((isMs ? 'Tarikh: ' : 'Date: ') + dateStr, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('ID: $certId', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.SizedBox(height: 50),
                pw.Text(isMs ? 'Diiktiraf oleh APM / NADMA Malaysia' : 'Certified by APM / NADMA Malaysia',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final isMs = context.watch<LocaleProvider>().locale.languageCode == 'ms';
    final certId = 'CERT-${widget.missionId.substring(0, 8).toUpperCase()}';
    final volunteerName = widget.data['volunteer_name'] as String? ?? 'Sukarelawan FloodSense';
    final sosId = widget.data['sos_id'] as String? ?? '';
    final date = DateTime.now();
    final dateStr = isMs ? '${date.day} ${_month(date.month)} ${date.year}' : '${_monthEn(date.month)} ${date.day}, ${date.year}';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const LocText('Sijil Perkhidmatan', 'Service Certificate'),
        actions: [
          IconButton(
            onPressed: () => _sharePDF(certId, volunteerName, sosId, dateStr, isMs),
            icon: const Icon(Icons.share_outlined),
            tooltip: isMs ? 'Kongsi' : 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _buildCertificateCard(certId, volunteerName, sosId, dateStr, isMs),
          const SizedBox(height: 24),
          _buildQRSection(certId, isMs),
          const SizedBox(height: 24),
          _buildDetailsSection(isMs),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, 
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : () => _downloadPDF(certId, volunteerName, sosId, dateStr, isMs),
              icon: _isDownloading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.download_outlined),
              label: Text(_isDownloading 
                  ? (isMs ? 'MEMUAT TURUN...' : 'DOWNLOADING...') 
                  : (isMs ? 'MUAT TURUN PDF' : 'DOWNLOAD PDF')),
            ),
          ),
          const SizedBox(height: 8),
          Text(isMs ? '* Sijil ini boleh disahkan di FloodSense.my/verify' : '* Certificate verifiable at FloodSense.my/verify',
              textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF505050), fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildCertificateCard(String certId, String volunteerName, String sosId, String dateStr, bool isMs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF141414)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFB300).withAlpha(80), width: 1.5),
      ),
      child: Column(children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFFFB300).withAlpha(25), shape: BoxShape.circle),
            child: const Icon(Icons.verified, color: Color(0xFFFFB300), size: 28),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMs ? 'SIJIL PERKHIDMATAN' : 'SERVICE CERTIFICATE', style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
            Text(isMs ? 'SUKARELAWAN FLOODSENSE' : 'FLOODSENSE VOLUNTEER', style: const TextStyle(color: Color(0xFF757575), fontSize: 10, letterSpacing: 2)),
          ]),
        ]),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF2A2A2A)),
        const SizedBox(height: 16),
        Text(isMs ? 'Ini mengesahkan bahawa' : 'This certifies that', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF757575), fontSize: 13)),
        const SizedBox(height: 12),
        Text(volunteerName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFF5F5F5))),
        const SizedBox(height: 8),
        Text(isMs ? 'telah berjaya menyelamatkan mangsa banjir' : 'has successfully completed a flood rescue mission',
            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF757575), fontSize: 13)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF00C853).withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF00C853).withAlpha(60))),
          child: Text(isMs ? 'Misi $sosId' : 'Mission $sosId', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFF2A2A2A)),
        const SizedBox(height: 12),
        // Footer
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const LocText('Tarikh', 'Date', style: TextStyle(color: Color(0xFF505050), fontSize: 10)),
            Text(dateStr, style: const TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const LocText('ID Sijil', 'Certificate ID', style: TextStyle(color: Color(0xFF505050), fontSize: 10)),
            Text(certId, style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ]),
        const SizedBox(height: 12),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.apartment, color: Color(0xFF505050), size: 14),
          SizedBox(width: 4),
          LocText('Diiktiraf oleh APM', 'NADMA Malaysia', style: TextStyle(color: Color(0xFF505050), fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildQRSection(String certId, bool isMs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        const LocText('KOD PENGESAHAN', 'VERIFICATION QR', style: TextStyle(color: Color(0xFF757575), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        // QR placeholder (in production: use qr_flutter package)
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.qr_code_2, size: 120, color: Colors.black),
            Container(
              padding: const EdgeInsets.all(4),
              color: Colors.white,
              child: const Icon(Icons.flood, color: Color(0xFFE53935), size: 24),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(certId, style: const TextStyle(color: Color(0xFF757575), fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 4),
        const LocText('Imbas untuk sahkan', 'Scan to verify', style: TextStyle(color: Color(0xFF505050), fontSize: 11)),
      ]),
    );
  }

  Widget _buildDetailsSection(bool isMs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const LocText('MAKLUMAT TAMBAHAN', 'ADDITIONAL INFO', style: TextStyle(color: Color(0xFF757575), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const _DetailRow(label: 'Platform', value: 'FloodSense Malaysia'),
        _DetailRow(label: isMs ? 'Agensi' : 'Agency', value: 'APM / NADMA'),
        _DetailRow(label: isMs ? 'Jenis Misi' : 'Mission Type', value: isMs ? 'Menyelamat & Evakuasi' : 'Rescue & Evacuation'),
        _DetailRow(label: isMs ? 'Jenis Sijil' : 'Credential Type', value: isMs ? 'Sijil Digital Boleh Sah' : 'Verifiable Digital Certificate'),
      ]),
    );
  }

  static String _month(int m) => ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogs', 'Sep', 'Okt', 'Nov', 'Dis'][m];
  static String _monthEn(int m) => ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  Future<void> _sharePDF(String certId, String name, String sosId, String dateStr, bool isMs) async {
    setState(() => _isDownloading = true);
    try {
      final pdfBytes = await _buildPdfBytes(certId, name, sosId, dateStr, isMs);

      // Robust Web check: kIsWeb is the standard, identical(0, 0.0) is the fallback for JS env
      if (kIsWeb || identical(0, 0.0)) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                Uint8List.fromList(pdfBytes),
                name: '$certId.pdf',
                mimeType: 'application/pdf',
              )
            ],
            text: '${isMs ? "Sijil Perkhidmatan FloodSense" : "FloodSense Service Certificate"}: $name ($certId)',
          ),
        );
        return; // Ensure we exit and don't hit mobile code
      }

      // Mobile: save to temp file then open the native share sheet
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$certId.pdf');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${isMs ? "Sijil Perkhidmatan FloodSense" : "FloodSense Service Certificate"}: $name ($certId)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('REV2 - ${isMs ? "Gagal berkongsi" : "Share failed"}: $e',
              style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Color(0xFF757575), fontSize: 13)),
      Text(value, style: const TextStyle(color: Color(0xFFF5F5F5), fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}
