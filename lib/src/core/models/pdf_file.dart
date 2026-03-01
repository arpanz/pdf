class PdfFile {
  final String path;
  final String name;
  final int sizeBytes;
  final int pageCount;
  final bool isEncrypted;
  final DateTime processedDate;
  final String action;

  PdfFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.pageCount,
    this.isEncrypted = false,
    required this.processedDate,
    required this.action,
  });

  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  factory PdfFile.fromJson(Map<String, dynamic> json) {
    return PdfFile(
      path: json['path'] as String,
      name: json['name'] as String,
      sizeBytes: json['sizeBytes'] as int,
      pageCount: json['pageCount'] as int,
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      processedDate: DateTime.parse(json['processedDate'] as String),
      action: json['action'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'sizeBytes': sizeBytes,
      'pageCount': pageCount,
      'isEncrypted': isEncrypted,
      'processedDate': processedDate.toIso8601String(),
      'action': action,
    };
  }
}

class ProcessingResult {
  final bool success;
  final String outputPath;
  final String? error;

  ProcessingResult({
    required this.success,
    required this.outputPath,
    this.error,
  });
}

enum PdfAction {
  merge,
  split,
  compress,
  protect,
  unlock,
  pdfToImage,
}

extension PdfActionExtension on PdfAction {
  String get displayName {
    switch (this) {
      case PdfAction.merge:
        return 'Merged';
      case PdfAction.split:
        return 'Split';
      case PdfAction.compress:
        return 'Compressed';
      case PdfAction.protect:
        return 'Protected';
      case PdfAction.unlock:
        return 'Unlocked';
      case PdfAction.pdfToImage:
        return 'Converted';
    }
  }

  String get icon {
    switch (this) {
      case PdfAction.merge:
        return '📄➕📄';
      case PdfAction.split:
        return '✂️';
      case PdfAction.compress:
        return '🗜️';
      case PdfAction.protect:
        return '🔒';
      case PdfAction.unlock:
        return '🔓';
      case PdfAction.pdfToImage:
        return '🖼️';
    }
  }
}
