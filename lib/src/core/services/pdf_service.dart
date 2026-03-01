import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/pdf_file.dart';

class PdfService {
  static const int maxFreeFileSize = 5 * 1024 * 1024; // 5MB
  static const int maxFreePages = 10;

  Future<String> get _outputDirectory async {
    final docsDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(docsDir.path, 'BatchPDF'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir.path;
  }

  String _generateOutputFilename(String prefix, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = const Uuid().v4().substring(0, 8);
    return '${prefix}_${timestamp}_$uuid.$extension';
  }

  Future<bool> checkFileSizeLimit(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    final size = await file.length();
    return size <= maxFreeFileSize;
  }

  Future<bool> checkPageLimit(String filePath) async {
    // This is a simplified check - in production, you'd use a PDF library
    // For now, we assume files are under the limit until proven otherwise
    return true;
  }

  Future<ProcessingResult> mergePdfs(List<String> inputPaths) async {
    try {
      final outputDir = await _outputDirectory;
      final outputPath = p.join(outputDir, _generateOutputFilename('merged', 'pdf'));
      
      // For now, we'll use a simple copy if there's only one file
      // In production, this would call the Rust merge function
      if (inputPaths.length == 1) {
        final file = File(inputPaths[0]);
        await file.copy(outputPath);
        return ProcessingResult(success: true, outputPath: outputPath);
      }

      // Simulate processing time
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Copy the first file as a placeholder
      // In production, this would be the actual merged PDF from Rust
      final file = File(inputPaths[0]);
      await file.copy(outputPath);
      
      return ProcessingResult(success: true, outputPath: outputPath);
    } catch (e) {
      return ProcessingResult(success: false, outputPath: '', error: e.toString());
    }
  }

  Future<ProcessingResult> splitPdf(String inputPath, List<int> pages) async {
    try {
      final outputDir = await _outputDirectory;
      final outputPath = p.join(outputDir, _generateOutputFilename('split', 'pdf'));
      
      // Copy the file as a placeholder
      // In production, this would call the Rust split function
      final file = File(inputPath);
      await file.copy(outputPath);
      
      return ProcessingResult(success: true, outputPath: outputPath);
    } catch (e) {
      return ProcessingResult(success: false, outputPath: '', error: e.toString());
    }
  }

  Future<ProcessingResult> compressPdf(String inputPath, int level) async {
    try {
      final outputDir = await _outputDirectory;
      final outputPath = p.join(outputDir, _generateOutputFilename('compressed', 'pdf'));
      
      // Copy the file as a placeholder
      // In production, this would call the Rust compress function
      final file = File(inputPath);
      await file.copy(outputPath);
      
      return ProcessingResult(success: true, outputPath: outputPath);
    } catch (e) {
      return ProcessingResult(success: false, outputPath: '', error: e.toString());
    }
  }

  Future<ProcessingResult> protectPdf(String inputPath, String password) async {
    try {
      final outputDir = await _outputDirectory;
      final outputPath = p.join(outputDir, _generateOutputFilename('protected', 'pdf'));
      
      // Copy the file as a placeholder
      // In production, this would call the Rust encrypt function
      final file = File(inputPath);
      await file.copy(outputPath);
      
      return ProcessingResult(success: true, outputPath: outputPath);
    } catch (e) {
      return ProcessingResult(success: false, outputPath: '', error: e.toString());
    }
  }

  Future<ProcessingResult> unlockPdf(String inputPath, String password) async {
    try {
      final outputDir = await _outputDirectory;
      final outputPath = p.join(outputDir, _generateOutputFilename('unlocked', 'pdf'));
      
      // Copy the file as a placeholder
      // In production, this would call the Rust decrypt function
      final file = File(inputPath);
      await file.copy(outputPath);
      
      return ProcessingResult(success: true, outputPath: outputPath);
    } catch (e) {
      return ProcessingResult(success: false, outputPath: '', error: e.toString());
    }
  }

  Future<String> pdfToImages(String inputPath) async {
    final outputDir = await _outputDirectory;
    final imagesDir = p.join(outputDir, _generateOutputFilename('images', ''));
    await Directory(imagesDir).create(recursive: true);
    return imagesDir;
  }

  Future<int> getPageCount(String filePath) async {
    // Simplified - in production would use a PDF library
    return 1;
  }

  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return await file.length();
  }

  Future<List<PdfFile>> getProcessedFiles() async {
    final outputDir = await _outputDirectory;
    final dir = Directory(outputDir);
    final files = <PdfFile>[];
    
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.pdf')) {
          final stat = await entity.stat();
          final name = p.basename(entity.path);
          final action = _inferAction(name);
          
          files.add(PdfFile(
            path: entity.path,
            name: name,
            sizeBytes: stat.size,
            pageCount: 1, // Would need PDF library to get actual count
            processedDate: stat.modified,
            action: action,
          ));
        }
      }
    }
    
    // Sort by date, newest first
    files.sort((a, b) => b.processedDate.compareTo(a.processedDate));
    return files;
  }

  String _inferAction(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('merged')) return 'Merged';
    if (lower.contains('split')) return 'Split';
    if (lower.contains('compressed')) return 'Compressed';
    if (lower.contains('protected')) return 'Protected';
    if (lower.contains('unlocked')) return 'Unlocked';
    return 'Processed';
  }

  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
