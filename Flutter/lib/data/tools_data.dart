import 'package:flutter/material.dart';

import '../models/tool_model.dart';
import '../theme/app_colors.dart';

/// Farvixo mobile tool catalog (subset of the 128-tool web catalog).
class ToolsData {
  ToolsData._();

  static const List<ToolCategory> categories = [
    ToolCategory(
        id: 'pdf',
        name: 'PDF Tools',
        icon: Icons.picture_as_pdf_rounded,
        color: AppColors.accentPdf),
    ToolCategory(
        id: 'image',
        name: 'Image Tools',
        icon: Icons.image_rounded,
        color: AppColors.accentImage),
    ToolCategory(
        id: 'video',
        name: 'Video Tools',
        icon: Icons.play_circle_rounded,
        color: AppColors.accentVideo),
    ToolCategory(
        id: 'audio',
        name: 'Audio Tools',
        icon: Icons.music_note_rounded,
        color: AppColors.accentAudio),
    ToolCategory(
        id: 'ai',
        name: 'AI Tools',
        icon: Icons.auto_awesome_rounded,
        color: AppColors.accentAi),
    ToolCategory(
        id: 'dev',
        name: 'Developer Tools',
        icon: Icons.code_rounded,
        color: AppColors.accentDev),
    ToolCategory(
        id: 'text',
        name: 'Text Tools',
        icon: Icons.text_fields_rounded,
        color: AppColors.accentText),
    ToolCategory(
        id: 'utility',
        name: 'Utilities',
        icon: Icons.build_rounded,
        color: AppColors.accentUtility),
  ];

  static const List<Tool> tools = [
    // PDF
    Tool(
        id: 'pdf-to-word',
        name: 'PDF to Word',
        description: 'Convert PDF files to editable Word documents.',
        categoryId: 'pdf',
        icon: Icons.description_rounded,
        badge: ToolBadge.popular),
    Tool(
        id: 'merge-pdf',
        name: 'Merge PDF',
        description: 'Combine multiple PDFs into a single file.',
        categoryId: 'pdf',
        icon: Icons.merge_rounded),
    Tool(
        id: 'compress-pdf',
        name: 'Compress PDF',
        description: 'Reduce PDF size without losing quality.',
        categoryId: 'pdf',
        icon: Icons.compress_rounded,
        badge: ToolBadge.popular),
    Tool(
        id: 'split-pdf',
        name: 'Split PDF',
        description: 'Split a PDF into multiple documents.',
        categoryId: 'pdf',
        icon: Icons.call_split_rounded),
    Tool(
        id: 'pdf-ocr',
        name: 'PDF OCR',
        description: 'Make scanned PDFs searchable with OCR.',
        categoryId: 'pdf',
        icon: Icons.document_scanner_rounded,
        badge: ToolBadge.ai),
    Tool(
        id: 'protect-pdf',
        name: 'Protect PDF',
        description: 'Add password protection to your PDFs.',
        categoryId: 'pdf',
        icon: Icons.lock_rounded),

    // Image
    Tool(
        id: 'image-compressor',
        name: 'Image Compressor',
        description: 'Shrink image size while keeping quality.',
        categoryId: 'image',
        icon: Icons.photo_size_select_small_rounded,
        badge: ToolBadge.popular),
    Tool(
        id: 'background-remover',
        name: 'Background Remover',
        description: 'Remove image backgrounds with AI.',
        categoryId: 'image',
        icon: Icons.auto_fix_high_rounded,
        badge: ToolBadge.ai),
    Tool(
        id: 'image-resizer',
        name: 'Image Resizer',
        description: 'Resize images to any dimension.',
        categoryId: 'image',
        icon: Icons.aspect_ratio_rounded),
    Tool(
        id: 'image-converter',
        name: 'Image Converter',
        description: 'Convert between JPG, PNG, WebP and more.',
        categoryId: 'image',
        icon: Icons.swap_horiz_rounded),
    Tool(
        id: 'image-ocr',
        name: 'Image OCR',
        description: 'Extract text from any image.',
        categoryId: 'image',
        icon: Icons.text_snippet_rounded,
        badge: ToolBadge.ai),
    Tool(
        id: 'image-upscaler',
        name: 'AI Image Upscaler',
        description: 'Upscale images to higher resolution with AI.',
        categoryId: 'image',
        icon: Icons.zoom_out_map_rounded,
        badge: ToolBadge.isNew),

    // Video
    Tool(
        id: 'video-converter',
        name: 'Video Converter',
        description: 'Convert videos between formats.',
        categoryId: 'video',
        icon: Icons.movie_rounded),
    Tool(
        id: 'video-compressor',
        name: 'Video Compressor',
        description: 'Compress videos for easy sharing.',
        categoryId: 'video',
        icon: Icons.video_settings_rounded,
        badge: ToolBadge.popular),
    Tool(
        id: 'video-trimmer',
        name: 'Video Trimmer',
        description: 'Cut and trim video clips.',
        categoryId: 'video',
        icon: Icons.content_cut_rounded),
    Tool(
        id: 'video-to-gif',
        name: 'Video to GIF',
        description: 'Turn video clips into animated GIFs.',
        categoryId: 'video',
        icon: Icons.gif_box_rounded),

    // Audio
    Tool(
        id: 'audio-converter',
        name: 'Audio Converter',
        description: 'Convert audio between MP3, WAV and more.',
        categoryId: 'audio',
        icon: Icons.audiotrack_rounded),
    Tool(
        id: 'audio-cutter',
        name: 'Audio Cutter',
        description: 'Trim and cut audio files.',
        categoryId: 'audio',
        icon: Icons.cut_rounded),
    Tool(
        id: 'text-to-speech',
        name: 'Text to Speech',
        description: 'Convert text into natural speech.',
        categoryId: 'audio',
        icon: Icons.record_voice_over_rounded,
        badge: ToolBadge.ai),
    Tool(
        id: 'speech-to-text',
        name: 'Speech to Text',
        description: 'Transcribe audio into text.',
        categoryId: 'audio',
        icon: Icons.mic_rounded,
        badge: ToolBadge.ai),

    // AI
    Tool(
        id: 'ai-chat',
        name: 'AI Chat',
        description: 'Chat with the Farvixo AI assistant.',
        categoryId: 'ai',
        icon: Icons.chat_bubble_rounded,
        badge: ToolBadge.ai),
    Tool(
        id: 'ai-writer',
        name: 'AI Writer',
        description: 'Generate long-form content with AI.',
        categoryId: 'ai',
        icon: Icons.edit_note_rounded,
        badge: ToolBadge.isNew),
    Tool(
        id: 'ai-summarizer',
        name: 'AI Summarizer',
        description: 'Summarize long text or documents.',
        categoryId: 'ai',
        icon: Icons.summarize_rounded,
        badge: ToolBadge.ai),
    Tool(
        id: 'ai-translator',
        name: 'AI Translator',
        description: 'Translate text between languages.',
        categoryId: 'ai',
        icon: Icons.translate_rounded,
        badge: ToolBadge.ai),
    Tool(
        id: 'ai-email-writer',
        name: 'AI Email Writer',
        description: 'Draft professional emails in seconds.',
        categoryId: 'ai',
        icon: Icons.mail_rounded,
        badge: ToolBadge.ai),

    // Developer
    Tool(
        id: 'json-formatter',
        name: 'JSON Formatter',
        description: 'Format and prettify JSON data.',
        categoryId: 'dev',
        icon: Icons.data_object_rounded),
    Tool(
        id: 'base64',
        name: 'Base64 Encoder',
        description: 'Encode and decode Base64 strings.',
        categoryId: 'dev',
        icon: Icons.swap_vert_rounded),
    Tool(
        id: 'uuid-generator',
        name: 'UUID Generator',
        description: 'Generate unique identifiers.',
        categoryId: 'dev',
        icon: Icons.fingerprint_rounded),
    Tool(
        id: 'hash-generator',
        name: 'Hash Generator',
        description: 'Generate MD5, SHA-256 and other hashes.',
        categoryId: 'dev',
        icon: Icons.tag_rounded),

    // Text
    Tool(
        id: 'word-counter',
        name: 'Word Counter',
        description: 'Count words, characters and sentences.',
        categoryId: 'text',
        icon: Icons.format_list_numbered_rounded),
    Tool(
        id: 'case-converter',
        name: 'Case Converter',
        description: 'Convert text case instantly.',
        categoryId: 'text',
        icon: Icons.text_rotation_none_rounded),
    Tool(
        id: 'text-compare',
        name: 'Text Compare',
        description: 'Find differences between two texts.',
        categoryId: 'text',
        icon: Icons.compare_arrows_rounded),

    // Utility
    Tool(
        id: 'qr-generator',
        name: 'QR Code Generator',
        description: 'Create QR codes for links and text.',
        categoryId: 'utility',
        icon: Icons.qr_code_rounded,
        badge: ToolBadge.popular),
    Tool(
        id: 'password-generator',
        name: 'Password Generator',
        description: 'Generate strong, secure passwords.',
        categoryId: 'utility',
        icon: Icons.password_rounded),
    Tool(
        id: 'unit-converter',
        name: 'Unit Converter',
        description: 'Convert length, weight, temperature and more.',
        categoryId: 'utility',
        icon: Icons.straighten_rounded),
    Tool(
        id: 'age-calculator',
        name: 'Age Calculator',
        description: 'Calculate exact age from date of birth.',
        categoryId: 'utility',
        icon: Icons.cake_rounded),
  ];

  static ToolCategory categoryOf(Tool tool) =>
      categories.firstWhere((c) => c.id == tool.categoryId);

  static ToolCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static Tool? toolById(String id) {
    for (final t in tools) {
      if (t.id == id) return t;
    }
    return null;
  }

  static List<Tool> byCategory(String categoryId) =>
      tools.where((t) => t.categoryId == categoryId).toList();

  static List<Tool> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return tools
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q))
        .toList();
  }
}
