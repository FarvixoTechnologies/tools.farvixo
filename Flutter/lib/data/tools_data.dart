import 'package:flutter/material.dart';

import '../models/tool_model.dart';
import '../theme/app_colors.dart';

/// Farvixo mobile tool catalog — 140 tools across 8 categories.
///
/// Tools with a registered engine in `ToolEngineRegistry` run fully
/// on-device (or via the Farvixo AI backend); the rest surface a premium
/// coming-soon state in the detail workspace.
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

    // ---------------- PDF ----------------
    Tool(
        id: 'pdf-converter',
        name: 'PDF Converter',
        description:
            'Convert PDF ↔ Word, Excel, PowerPoint, Images, Text and more.',
        categoryId: 'pdf',
        icon: Icons.sync_alt_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'pdf-to-word',
        name: 'PDF to Word',
        description: 'Convert PDF files to editable Word documents.',
        categoryId: 'pdf',
        icon: Icons.description_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'word-to-pdf',
        name: 'Word to PDF',
        description: 'Turn Word documents into shareable PDFs.',
        categoryId: 'pdf',
        icon: Icons.picture_as_pdf_rounded,),
    Tool(
        id: 'pdf-to-excel',
        name: 'PDF to Excel',
        description: 'Extract tables from PDFs into spreadsheets.',
        categoryId: 'pdf',
        icon: Icons.table_chart_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'excel-to-pdf',
        name: 'Excel to PDF',
        description: 'Turn spreadsheets into shareable PDFs.',
        categoryId: 'pdf',
        icon: Icons.picture_as_pdf_outlined,),
    Tool(
        id: 'merge-pdf',
        name: 'Merge PDF',
        description: 'Combine multiple PDFs into a single file.',
        categoryId: 'pdf',
        icon: Icons.merge_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'split-pdf',
        name: 'Split PDF',
        description: 'Extract any page range into a new PDF.',
        categoryId: 'pdf',
        icon: Icons.call_split_rounded,),
    Tool(
        id: 'compress-pdf',
        name: 'Compress PDF',
        description: 'Reduce PDF size without losing quality.',
        categoryId: 'pdf',
        icon: Icons.compress_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'image-to-pdf',
        name: 'Image to PDF',
        description: 'Combine photos into a single PDF.',
        categoryId: 'pdf',
        icon: Icons.collections_rounded,),
    Tool(
        id: 'pdf-to-text',
        name: 'PDF to Text',
        description: 'Extract all selectable text from a PDF.',
        categoryId: 'pdf',
        icon: Icons.notes_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'pdf-ocr',
        name: 'PDF OCR',
        description: 'Make scanned PDFs searchable with OCR.',
        categoryId: 'pdf',
        icon: Icons.document_scanner_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'protect-pdf',
        name: 'Protect PDF',
        description: 'Add password protection to your PDFs.',
        categoryId: 'pdf',
        icon: Icons.lock_rounded,),
    Tool(
        id: 'unlock-pdf',
        name: 'Unlock PDF',
        description: 'Remove a known password from a PDF.',
        categoryId: 'pdf',
        icon: Icons.lock_open_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'rotate-pdf',
        name: 'Rotate PDF',
        description: 'Rotate every page 90 or 180 degrees.',
        categoryId: 'pdf',
        icon: Icons.rotate_right_rounded,),
    Tool(
        id: 'watermark-pdf',
        name: 'Watermark PDF',
        description: 'Stamp a text watermark on every page.',
        categoryId: 'pdf',
        icon: Icons.branding_watermark_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'pdf-page-numbers',
        name: 'PDF Page Numbers',
        description: 'Add Page X of N footers automatically.',
        categoryId: 'pdf',
        icon: Icons.format_list_numbered_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'reverse-pdf',
        name: 'Reverse PDF',
        description: 'Flip the page order of a document.',
        categoryId: 'pdf',
        icon: Icons.swap_vert_rounded,),
    Tool(
        id: 'pdf-info',
        name: 'PDF Inspector',
        description: 'Pages, size, metadata and security at a glance.',
        categoryId: 'pdf',
        icon: Icons.info_rounded,),
    Tool(
        id: 'pdf-to-image',
        name: 'PDF to Image',
        description: 'Export PDF pages as images.',
        categoryId: 'pdf',
        icon: Icons.image_rounded,),

    // ---------------- Image ----------------
    Tool(
        id: 'image-compressor',
        name: 'Image Compressor',
        description: 'Shrink image size while keeping quality.',
        categoryId: 'image',
        icon: Icons.photo_size_select_small_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'image-resizer',
        name: 'Image Resizer',
        description: 'Resize images to any dimension.',
        categoryId: 'image',
        icon: Icons.aspect_ratio_rounded,),
    Tool(
        id: 'image-converter',
        name: 'Image Converter',
        description: 'Convert between JPG, PNG, BMP and more.',
        categoryId: 'image',
        icon: Icons.swap_horiz_rounded,),
    Tool(
        id: 'rotate-flip-image',
        name: 'Rotate & Flip',
        description: 'Rotate or mirror any image.',
        categoryId: 'image',
        icon: Icons.rotate_90_degrees_ccw_rounded,),
    Tool(
        id: 'image-crop',
        name: 'Image Crop',
        description: 'Center-crop to square, 16:9, 4:3 or 3:2.',
        categoryId: 'image',
        icon: Icons.crop_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'image-grayscale',
        name: 'Grayscale Filter',
        description: 'Convert photos to black & white.',
        categoryId: 'image',
        icon: Icons.filter_b_and_w_rounded,),
    Tool(
        id: 'image-sepia',
        name: 'Sepia Filter',
        description: 'Give photos a warm vintage tone.',
        categoryId: 'image',
        icon: Icons.filter_vintage_rounded,),
    Tool(
        id: 'image-invert',
        name: 'Invert Colors',
        description: 'Create striking color negatives.',
        categoryId: 'image',
        icon: Icons.invert_colors_rounded,),
    Tool(
        id: 'image-blur',
        name: 'Image Blur',
        description: 'Gaussian blur with strength presets.',
        categoryId: 'image',
        icon: Icons.blur_on_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'image-pixelate',
        name: 'Pixelate',
        description: 'Mosaic-censor any part of a photo.',
        categoryId: 'image',
        icon: Icons.grid_on_rounded,),
    Tool(
        id: 'image-enhance',
        name: 'Photo Enhancer',
        description: 'One-tap brightness, contrast and pop presets.',
        categoryId: 'image',
        icon: Icons.auto_awesome_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'image-info',
        name: 'Image Inspector',
        description: 'Dimensions, megapixels, aspect and size.',
        categoryId: 'image',
        icon: Icons.straighten_rounded,),
    Tool(
        id: 'image-to-base64',
        name: 'Image to Base64',
        description: 'Data-URI encode images for HTML/CSS.',
        categoryId: 'image',
        icon: Icons.code_rounded,),
    Tool(
        id: 'color-palette-extractor',
        name: 'Palette Extractor',
        description: 'Pull the dominant colours from any photo.',
        categoryId: 'image',
        icon: Icons.palette_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'image-ocr',
        name: 'Image OCR',
        description: 'Extract text from any image.',
        categoryId: 'image',
        icon: Icons.text_snippet_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'background-remover',
        name: 'Background Remover',
        description: 'Remove image backgrounds with AI.',
        categoryId: 'image',
        icon: Icons.auto_fix_high_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'image-upscaler',
        name: 'AI Image Upscaler',
        description: 'Upscale images to higher resolution with AI.',
        categoryId: 'image',
        icon: Icons.zoom_out_map_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'image-watermark',
        name: 'Image Watermark',
        description: 'Protect photos with a text watermark.',
        categoryId: 'image',
        icon: Icons.water_drop_rounded,),
    Tool(
        id: 'meme-generator',
        name: 'Meme Generator',
        description: 'Add classic top/bottom captions to images.',
        categoryId: 'image',
        icon: Icons.sentiment_very_satisfied_rounded,),

    // ---------------- Video ----------------
    Tool(
        id: 'video-converter',
        name: 'Video Converter',
        description: 'Convert videos between formats.',
        categoryId: 'video',
        icon: Icons.movie_rounded,),
    Tool(
        id: 'video-compressor',
        name: 'Video Compressor',
        description: 'Compress videos for easy sharing.',
        categoryId: 'video',
        icon: Icons.video_settings_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'video-trimmer',
        name: 'Video Trimmer',
        description: 'Cut and trim video clips.',
        categoryId: 'video',
        icon: Icons.content_cut_rounded,),
    Tool(
        id: 'video-to-gif',
        name: 'Video to GIF',
        description: 'Turn video clips into animated GIFs.',
        categoryId: 'video',
        icon: Icons.gif_box_rounded,),
    Tool(
        id: 'gif-to-video',
        name: 'GIF to Video',
        description: 'Convert animated GIFs into MP4 clips.',
        categoryId: 'video',
        icon: Icons.slideshow_rounded,),
    Tool(
        id: 'video-merger',
        name: 'Video Merger',
        description: 'Join multiple clips into one video.',
        categoryId: 'video',
        icon: Icons.playlist_add_rounded,),
    Tool(
        id: 'video-mute',
        name: 'Video Muter',
        description: 'Strip audio from any video.',
        categoryId: 'video',
        icon: Icons.volume_off_rounded,),
    Tool(
        id: 'video-speed',
        name: 'Video Speed',
        description: 'Speed up or slow down footage.',
        categoryId: 'video',
        icon: Icons.speed_rounded,),
    Tool(
        id: 'video-rotate',
        name: 'Video Rotate',
        description: 'Fix sideways or upside-down videos.',
        categoryId: 'video',
        icon: Icons.screen_rotation_rounded,),
    Tool(
        id: 'audio-extractor',
        name: 'Audio Extractor',
        description: 'Save a video soundtrack as audio.',
        categoryId: 'video',
        icon: Icons.music_video_rounded,),
    Tool(
        id: 'video-thumbnail',
        name: 'Thumbnail Grabber',
        description: 'Capture the perfect frame as an image.',
        categoryId: 'video',
        icon: Icons.photo_camera_rounded,),
    Tool(
        id: 'subtitle-tools',
        name: 'Subtitle Tools',
        description: 'Add or extract subtitles from videos.',
        categoryId: 'video',
        icon: Icons.subtitles_rounded,),
    Tool(
        id: 'video-watermark',
        name: 'Video Watermark',
        description: 'Brand your clips with a logo or text.',
        categoryId: 'video',
        icon: Icons.branding_watermark_rounded,),
    Tool(
        id: 'screen-recorder',
        name: 'Screen Recorder',
        description: 'Record your screen with audio.',
        categoryId: 'video',
        icon: Icons.fiber_manual_record_rounded,),

    // ---------------- Audio ----------------
    Tool(
        id: 'audio-converter',
        name: 'Audio Converter',
        description: 'Convert audio between MP3, WAV and more.',
        categoryId: 'audio',
        icon: Icons.audiotrack_rounded,),
    Tool(
        id: 'audio-cutter',
        name: 'Audio Cutter',
        description: 'Trim and cut audio files.',
        categoryId: 'audio',
        icon: Icons.cut_rounded,),
    Tool(
        id: 'audio-merger',
        name: 'Audio Merger',
        description: 'Join multiple tracks into one file.',
        categoryId: 'audio',
        icon: Icons.queue_music_rounded,),
    Tool(
        id: 'volume-booster',
        name: 'Volume Booster',
        description: 'Make quiet recordings louder.',
        categoryId: 'audio',
        icon: Icons.volume_up_rounded,),
    Tool(
        id: 'audio-speed',
        name: 'Audio Speed',
        description: 'Change playback speed without pitch shift.',
        categoryId: 'audio',
        icon: Icons.slow_motion_video_rounded,),
    Tool(
        id: 'audio-reverse',
        name: 'Audio Reverser',
        description: 'Play any sound backwards.',
        categoryId: 'audio',
        icon: Icons.replay_rounded,),
    Tool(
        id: 'text-to-speech',
        name: 'Text to Speech',
        description: 'Convert text into natural speech.',
        categoryId: 'audio',
        icon: Icons.record_voice_over_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'speech-to-text',
        name: 'Speech to Text',
        description: 'Transcribe audio into text.',
        categoryId: 'audio',
        icon: Icons.mic_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'ringtone-maker',
        name: 'Ringtone Maker',
        description: 'Cut the perfect ringtone from a song.',
        categoryId: 'audio',
        icon: Icons.notifications_active_rounded,),
    Tool(
        id: 'noise-reducer',
        name: 'Noise Reducer',
        description: 'Clean up background noise with AI.',
        categoryId: 'audio',
        icon: Icons.graphic_eq_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'audio-recorder',
        name: 'Audio Recorder',
        description: 'Record voice notes and audio.',
        categoryId: 'audio',
        icon: Icons.mic_none_rounded,),
    Tool(
        id: 'audio-metadata',
        name: 'Audio Tag Editor',
        description: 'Edit title, artist and album tags.',
        categoryId: 'audio',
        icon: Icons.sell_rounded,),
    Tool(
        id: 'audio-normalizer',
        name: 'Audio Normalizer',
        description: 'Even out loudness across tracks.',
        categoryId: 'audio',
        icon: Icons.equalizer_rounded,),

    // ---------------- AI ----------------
    Tool(
        id: 'ai-chat',
        name: 'AI Chat',
        description: 'Chat with the Farvixo AI assistant.',
        categoryId: 'ai',
        icon: Icons.chat_bubble_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'ai-image-generator',
        name: 'AI Image Generator',
        description: 'Create stunning images from text.',
        categoryId: 'ai',
        icon: Icons.brush_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'ai-writer',
        name: 'AI Writer',
        description: 'Generate long-form content with AI.',
        categoryId: 'ai',
        icon: Icons.edit_note_rounded,),
    Tool(
        id: 'ai-summarizer',
        name: 'AI Summarizer',
        description: 'Summarize long text or documents.',
        categoryId: 'ai',
        icon: Icons.summarize_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'ai-translator',
        name: 'AI Translator',
        description: 'Translate text between languages.',
        categoryId: 'ai',
        icon: Icons.translate_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'ai-email-writer',
        name: 'AI Email Writer',
        description: 'Draft professional emails in seconds.',
        categoryId: 'ai',
        icon: Icons.mail_rounded,
        badge: ToolBadge.ai,),
    Tool(
        id: 'grammar-checker',
        name: 'Grammar Checker',
        description: 'Fix grammar, spelling and punctuation.',
        categoryId: 'ai',
        icon: Icons.spellcheck_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'paraphraser',
        name: 'Paraphraser',
        description: 'Rephrase text while keeping its meaning.',
        categoryId: 'ai',
        icon: Icons.sync_alt_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'ai-caption-generator',
        name: 'Caption Generator',
        description: 'Catchy social captions with emojis.',
        categoryId: 'ai',
        icon: Icons.photo_filter_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'hashtag-generator',
        name: 'Hashtag Generator',
        description: 'Effective hashtags for any post.',
        categoryId: 'ai',
        icon: Icons.tag_rounded,),
    Tool(
        id: 'blog-outliner',
        name: 'Blog Outliner',
        description: 'Structured outlines for any topic.',
        categoryId: 'ai',
        icon: Icons.segment_rounded,),
    Tool(
        id: 'product-description',
        name: 'Product Descriptions',
        description: 'Persuasive e-commerce copy in seconds.',
        categoryId: 'ai',
        icon: Icons.shopping_bag_rounded,),
    Tool(
        id: 'business-name-generator',
        name: 'Name Generator',
        description: 'Brandable business name ideas.',
        categoryId: 'ai',
        icon: Icons.storefront_rounded,),
    Tool(
        id: 'ai-story-writer',
        name: 'Story Writer',
        description: 'Short stories from any premise.',
        categoryId: 'ai',
        icon: Icons.auto_stories_rounded,),
    Tool(
        id: 'resume-bullet-writer',
        name: 'Resume Bullets',
        description: 'Quantified bullet points that impress.',
        categoryId: 'ai',
        icon: Icons.work_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'interview-questions',
        name: 'Interview Prep',
        description: 'Likely questions with answer outlines.',
        categoryId: 'ai',
        icon: Icons.record_voice_over_rounded,),
    Tool(
        id: 'quiz-generator',
        name: 'Quiz Generator',
        description: 'Multiple-choice quizzes on any topic.',
        categoryId: 'ai',
        icon: Icons.quiz_rounded,),
    Tool(
        id: 'prompt-improver',
        name: 'Prompt Improver',
        description: 'Make your AI prompts dramatically better.',
        categoryId: 'ai',
        icon: Icons.tips_and_updates_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'notes-cleaner',
        name: 'Notes Cleaner',
        description: 'Rough notes to organized bullet notes.',
        categoryId: 'ai',
        icon: Icons.sticky_note_2_rounded,),
    Tool(
        id: 'ai-code-explainer',
        name: 'Code Explainer',
        description: 'Understand any code, step by step.',
        categoryId: 'ai',
        icon: Icons.terminal_rounded,
        badge: ToolBadge.isNew,),

    // ---------------- Developer ----------------
    Tool(
        id: 'json-formatter',
        name: 'JSON Formatter',
        description: 'Format, validate and prettify JSON.',
        categoryId: 'dev',
        icon: Icons.data_object_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'base64',
        name: 'Base64 Encoder',
        description: 'Encode and decode Base64 strings.',
        categoryId: 'dev',
        icon: Icons.swap_vert_rounded,),
    Tool(
        id: 'uuid-generator',
        name: 'UUID Generator',
        description: 'Generate unique identifiers.',
        categoryId: 'dev',
        icon: Icons.fingerprint_rounded,),
    Tool(
        id: 'hash-generator',
        name: 'Hash Generator',
        description: 'MD5, SHA-1, SHA-256 and SHA-512 hashes.',
        categoryId: 'dev',
        icon: Icons.tag_rounded,),
    Tool(
        id: 'url-encoder',
        name: 'URL Encoder',
        description: 'Percent-encode or decode URL components.',
        categoryId: 'dev',
        icon: Icons.link_rounded,),
    Tool(
        id: 'html-entities',
        name: 'HTML Entities',
        description: 'Escape or unescape HTML safely.',
        categoryId: 'dev',
        icon: Icons.code_rounded,),
    Tool(
        id: 'jwt-decoder',
        name: 'JWT Decoder',
        description: 'Inspect JWT headers, payloads and expiry.',
        categoryId: 'dev',
        icon: Icons.key_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'color-converter',
        name: 'Color Converter',
        description: 'HEX, RGB and HSL conversions.',
        categoryId: 'dev',
        icon: Icons.palette_rounded,),
    Tool(
        id: 'timestamp-converter',
        name: 'Timestamp Converter',
        description: 'Unix epoch and human-readable dates.',
        categoryId: 'dev',
        icon: Icons.schedule_rounded,),
    Tool(
        id: 'number-base-converter',
        name: 'Base Converter',
        description: 'Binary, octal, decimal and hex.',
        categoryId: 'dev',
        icon: Icons.calculate_rounded,),
    Tool(
        id: 'roman-numerals',
        name: 'Roman Numerals',
        description: 'Numbers and Roman numerals both ways.',
        categoryId: 'dev',
        icon: Icons.account_balance_rounded,),
    Tool(
        id: 'csv-to-json',
        name: 'CSV to JSON',
        description: 'Turn spreadsheets into structured JSON.',
        categoryId: 'dev',
        icon: Icons.table_rows_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'json-to-csv',
        name: 'JSON to CSV',
        description: 'Flatten JSON arrays into CSV tables.',
        categoryId: 'dev',
        icon: Icons.table_chart_rounded,),
    Tool(
        id: 'markdown-to-html',
        name: 'Markdown to HTML',
        description: 'Convert Markdown into clean HTML.',
        categoryId: 'dev',
        icon: Icons.html_rounded,),
    Tool(
        id: 'css-minifier',
        name: 'CSS Minifier',
        description: 'Strip comments and whitespace from CSS.',
        categoryId: 'dev',
        icon: Icons.compress_rounded,),
    Tool(
        id: 'html-to-text',
        name: 'HTML to Text',
        description: 'Extract readable text from any HTML.',
        categoryId: 'dev',
        icon: Icons.text_fields_rounded,),
    Tool(
        id: 'token-generator',
        name: 'Token Generator',
        description: 'Secure random API keys and tokens.',
        categoryId: 'dev',
        icon: Icons.vpn_key_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'json-escape',
        name: 'JSON Escape',
        description: 'Escape or unescape JSON string literals.',
        categoryId: 'dev',
        icon: Icons.format_quote_rounded,),
    Tool(
        id: 'ip-subnet-calculator',
        name: 'Subnet Calculator',
        description: 'CIDR to network, broadcast and hosts.',
        categoryId: 'dev',
        icon: Icons.lan_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'file-to-base64',
        name: 'File to Base64',
        description: 'Encode any small file for embedding.',
        categoryId: 'dev',
        icon: Icons.attach_file_rounded,),
    Tool(
        id: 'http-status-codes',
        name: 'HTTP Status Codes',
        description: 'What every status code actually means.',
        categoryId: 'dev',
        icon: Icons.http_rounded,),
    Tool(
        id: 'lorem-ipsum-generator',
        name: 'Lorem Ipsum',
        description: 'Placeholder text for your designs.',
        categoryId: 'dev',
        icon: Icons.notes_rounded,),

    // ---------------- Text ----------------
    Tool(
        id: 'word-counter',
        name: 'Word Counter',
        description: 'Count words, characters and sentences.',
        categoryId: 'text',
        icon: Icons.format_list_numbered_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'character-counter',
        name: 'Character Counter',
        description: 'Precise character and line counts.',
        categoryId: 'text',
        icon: Icons.pin_rounded,),
    Tool(
        id: 'case-converter',
        name: 'Case Converter',
        description: 'UPPER, lower, Title and Sentence case.',
        categoryId: 'text',
        icon: Icons.text_rotation_none_rounded,),
    Tool(
        id: 'text-compare',
        name: 'Text Compare',
        description: 'Find differences between two texts.',
        categoryId: 'text',
        icon: Icons.compare_arrows_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'reverse-text',
        name: 'Text Reverser',
        description: 'Reverse characters, words or lines.',
        categoryId: 'text',
        icon: Icons.swap_horiz_rounded,),
    Tool(
        id: 'sort-lines',
        name: 'Line Sorter',
        description: 'Sort A-Z, by length, or shuffle lines.',
        categoryId: 'text',
        icon: Icons.sort_by_alpha_rounded,),
    Tool(
        id: 'remove-duplicate-lines',
        name: 'Dedupe Lines',
        description: 'Strip duplicate lines instantly.',
        categoryId: 'text',
        icon: Icons.filter_list_rounded,),
    Tool(
        id: 'text-cleaner',
        name: 'Text Cleaner',
        description: 'Kill extra spaces and blank lines.',
        categoryId: 'text',
        icon: Icons.cleaning_services_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'slug-generator',
        name: 'Slug Generator',
        description: 'URL-friendly slugs from any title.',
        categoryId: 'text',
        icon: Icons.link_rounded,),
    Tool(
        id: 'line-break-remover',
        name: 'Line Break Remover',
        description: 'Join wrapped lines into paragraphs.',
        categoryId: 'text',
        icon: Icons.wrap_text_rounded,),
    Tool(
        id: 'find-replace',
        name: 'Find & Replace',
        description: 'Bulk replace across any text.',
        categoryId: 'text',
        icon: Icons.find_replace_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'binary-translator',
        name: 'Binary Translator',
        description: 'Text and binary, both directions.',
        categoryId: 'text',
        icon: Icons.memory_rounded,),
    Tool(
        id: 'morse-code',
        name: 'Morse Code',
        description: 'Encode and decode Morse signals.',
        categoryId: 'text',
        icon: Icons.more_horiz_rounded,),
    Tool(
        id: 'caesar-cipher',
        name: 'Caesar Cipher',
        description: 'ROT13 and classic shift ciphers.',
        categoryId: 'text',
        icon: Icons.lock_person_rounded,),
    Tool(
        id: 'text-extractor',
        name: 'Text Extractor',
        description: 'Pull emails, URLs and numbers from text.',
        categoryId: 'text',
        icon: Icons.manage_search_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'word-frequency',
        name: 'Word Frequency',
        description: 'Your most-used words, ranked.',
        categoryId: 'text',
        icon: Icons.bar_chart_rounded,),
    Tool(
        id: 'number-to-words',
        name: 'Number to Words',
        description: 'Numbers in words, Indian & International.',
        categoryId: 'text',
        icon: Icons.onetwothree_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'text-repeater',
        name: 'Text Repeater',
        description: 'Repeat any text N times.',
        categoryId: 'text',
        icon: Icons.repeat_rounded,),

    // ---------------- Utility ----------------
    Tool(
        id: 'qr-generator',
        name: 'QR Code Generator',
        description: 'Create QR codes for links and text.',
        categoryId: 'utility',
        icon: Icons.qr_code_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'qr-scanner',
        name: 'QR Scanner',
        description: 'Scan QR codes from camera photos or gallery.',
        categoryId: 'utility',
        icon: Icons.qr_code_scanner_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'password-generator',
        name: 'Password Generator',
        description: 'Generate strong, secure passwords.',
        categoryId: 'utility',
        icon: Icons.password_rounded,),
    Tool(
        id: 'password-strength',
        name: 'Password Strength',
        description: 'How strong is your password, really?',
        categoryId: 'utility',
        icon: Icons.security_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'unit-converter',
        name: 'Unit Converter',
        description: 'Length, weight, temperature, data, speed.',
        categoryId: 'utility',
        icon: Icons.straighten_rounded,),
    Tool(
        id: 'age-calculator',
        name: 'Age Calculator',
        description: 'Exact age plus next-birthday countdown.',
        categoryId: 'utility',
        icon: Icons.cake_rounded,),
    Tool(
        id: 'bmi-calculator',
        name: 'BMI Calculator',
        description: 'Body-mass index with healthy range.',
        categoryId: 'utility',
        icon: Icons.monitor_weight_rounded,),
    Tool(
        id: 'percentage-calculator',
        name: 'Percentage Calculator',
        description: 'Percent of, what percent, and change.',
        categoryId: 'utility',
        icon: Icons.percent_rounded,),
    Tool(
        id: 'emi-calculator',
        name: 'EMI Calculator',
        description: 'Monthly payments for any loan.',
        categoryId: 'utility',
        icon: Icons.account_balance_rounded,
        badge: ToolBadge.popular,),
    Tool(
        id: 'interest-calculator',
        name: 'Interest Calculator',
        description: 'Simple and compound growth.',
        categoryId: 'utility',
        icon: Icons.trending_up_rounded,),
    Tool(
        id: 'discount-calculator',
        name: 'Discount Calculator',
        description: 'Final price after any discount.',
        categoryId: 'utility',
        icon: Icons.local_offer_rounded,),
    Tool(
        id: 'tip-calculator',
        name: 'Tip & Split',
        description: 'Tip and per-person bill splitting.',
        categoryId: 'utility',
        icon: Icons.restaurant_rounded,),
    Tool(
        id: 'gst-calculator',
        name: 'GST Calculator',
        description: 'Add or remove GST/VAT from amounts.',
        categoryId: 'utility',
        icon: Icons.receipt_long_rounded,
        badge: ToolBadge.isNew,),
    Tool(
        id: 'date-difference',
        name: 'Date Difference',
        description: 'Days, weeks and months between dates.',
        categoryId: 'utility',
        icon: Icons.date_range_rounded,),
    Tool(
        id: 'fuel-cost-calculator',
        name: 'Fuel Cost',
        description: 'Trip fuel needs and total cost.',
        categoryId: 'utility',
        icon: Icons.local_gas_station_rounded,),
    Tool(
        id: 'random-number',
        name: 'Random Number',
        description: 'Fair random numbers in any range.',
        categoryId: 'utility',
        icon: Icons.casino_rounded,),
    Tool(
        id: 'dice-roller',
        name: 'Dice & Coin',
        description: 'Flip a coin or roll D6 / D20.',
        categoryId: 'utility',
        icon: Icons.sports_esports_rounded,),
    Tool(
        id: 'card-validator',
        name: 'Card Validator',
        description: 'Luhn-check card numbers, fully offline.',
        categoryId: 'utility',
        icon: Icons.credit_card_rounded,),
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
