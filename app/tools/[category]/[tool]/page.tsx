import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import Icon from '@/components/Icon';
import ToolCard from '@/components/ToolCard';
import ToolRunner from '@/components/tool/ToolRunner';
import ToolUsageStat from '@/components/tool/ToolUsageStat';
import FeatureStrip from '@/components/homepage/FeatureStrip';
import { ToolMidAd, ToolPreFooterAd, ToolSidebarAd, ToolSmartlink } from '@/components/ads/ToolPageAds';
import { getCategory, type Category } from '@/data/categories';
import { getTool, getToolsByCategory, tools, type Tool } from '@/data/tools';
import { toolMetadata, defaultToolFaq, toolJsonLd, type Faq } from '@/lib/seo';

interface Props { params: Promise<{ category: string; tool: string }> }

export function generateStaticParams() {
  return tools.map((t) => ({ category: t.category, tool: t.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { tool: slug } = await params;
  const tool = getTool(slug);
  if (!tool) return {};
  const cat = getCategory(tool.category);

  if (slug === 'pdf-converter') {
    return {
      title: 'PDF Converter - Convert PDF to Word, Excel, JPG & More Free | ToolNest',
      description: 'Convert PDF to Word, Excel, PowerPoint, JPG, or convert any file to PDF - free, fast, and secure. No signup required. 100% browser-based processing.',
    };
  }

  if (slug === 'pan-card-photo-resizer') {
    return {
      title: 'PAN Card Photo Resizer — NSDL & UTI AI Tool with Compliance Check | ToolNest',
      description: 'Free AI PAN card photo, signature & document resizer for NSDL (Protean) and UTIITSL. Auto face crop, white background, DPI fix, 12-point compliance validator. 100% private.',
    };
  }

  if (slug === 'image-compressor') {
    return {
      title: 'Image Compressor - Compress Images Online Free | AVIF, WebP, JPEG, PNG | ToolNest',
      description: 'Compress images up to 90% smaller with AI-powered optimization. Supports AVIF, WebP, JPEG, PNG. Batch processing, target file size, social media presets. 100% private — runs in your browser.',
    };
  }

  if (slug === 'video-converter') {
    return {
      title: 'Video Converter — MP4, WebM, MKV, GIF & MP3 | AI Analysis & Batch | ToolNest',
      description: 'Convert videos to MP4, WebM, MKV, MOV, GIF or extract MP3/AAC. AI smart analysis, social presets (YouTube, Instagram, TikTok), batch queue, trim & rotate. 100% private FFmpeg in your browser.',
    };
  }

  if (slug === 'audio-converter') {
    return {
      title: 'Audio Converter — MP3, WAV, FLAC, AAC & AI Enhancement | ToolNest',
      description: 'Convert audio to MP3, WAV, FLAC, AAC, OGG, OPUS with AI analysis, noise removal, podcast presets, waveform preview & batch queue. 100% private FFmpeg in your browser.',
    };
  }

  if (slug === 'pdf-to-word') {
    return {
      title: 'PDF to Word Converter — Free OCR, AI Layout & Indic Support | ToolNest',
      description: 'Convert PDF to editable DOCX with AI layout repair, table detection, Bengali/Hindi OCR, batch mode & confidence score. 100% private browser processing — better than iLovePDF for Indian documents.',
    };
  }

  if (slug === 'compress-pdf') {
    return {
      title: 'PDF Compressor — AI Smart Compression, Batch & Quality Report | ToolNest',
      description: 'Compress PDF files up to 90% smaller with AI smart modes — email, web, print, lossless. Batch queue, compression report, password PDF support. Free & 100% private.',
    };
  }

  if (slug === 'background-remover') {
    return {
      title: 'Background Remover — AI Ultra HD Cutout, Hair Refine & Batch | ToolNest',
      description: 'Remove image backgrounds with AI — hair refinement, erase/restore brush, 14 background presets, batch ZIP export. Free, unlimited, 100% browser-private.',
    };
  }

  if (slug === 'merge-pdf') {
    return {
      title: 'Merge PDF — AI Organize, 10 Merge Modes & Premium Workflow | ToolNest',
      description: 'Merge multiple PDFs with AI page analysis, drag reorder, optimize modes for PAN/passport/book, batch merge. Free & 100% private browser processing.',
    };
  }

  if (slug === 'image-to-pdf') {
    return {
      title: 'Image to PDF — AI Batch Convert, Organize & Optimize | ToolNest',
      description: 'Convert JPG, PNG, WEBP, HEIC to PDF with AI analysis, drag timeline, page size control, compression, watermark & password. Free, 100% private browser processing.',
    };
  }

  if (slug === 'ai-chat') {
    return {
      title: 'AI Chat Assistant — 6 Personas, Streaming, History & Markdown | ToolNest',
      description: 'Free advanced AI chat powered by Gemini — General, Code, Creative, Analyst, Teacher modes. Chat history, PDF attach, temperature control, export & regenerate.',
    };
  }

  if (slug === 'ai-pdf-assistant') {
    return {
      title: 'AI PDF Assistant — Chat With Your PDF, Summarize & Extract | ToolNest',
      description: 'Upload any PDF and ask questions — summaries, key facts, tables, action items. Powered by Gemini with streaming answers. Free & private.',
    };
  }

  if (slug === 'age-calculator') {
    return {
      title: 'Age Calculator Pro — Exact Age in Years, Months, Days & Seconds | ToolNest',
      description: 'Calculate your exact age with leap-year accuracy. Birthday countdown, zodiac sign, milestones, life statistics, AI insights. 100% free, private, runs in your browser.',
    };
  }

  if (slug === 'world-weather-pro') {
    const title = 'World Weather Pro — Live Weather, 14-Day Forecast, AQI & Radar Map | ToolNest';
    const description = 'Free live weather app: real-time conditions, hourly timeline, 7 & 14-day forecast, air quality index, interactive radar map, sunrise/sunset, moon phase and AI insights for any city worldwide. No API key, no signup, 100% private.';
    const url = 'https://toolnestfm.com/tools/utility/world-weather-pro';
    const og = 'https://toolnestfm.com/api/og?title=World+Weather+Pro&subtitle=Live+forecast%2C+AQI+%26+radar&badge=NEW';
    return {
      title,
      description,
      keywords: [
        'weather', 'live weather', 'weather today', 'weather forecast', 'world weather',
        'hourly forecast', '7 day forecast', '14 day forecast', 'air quality index', 'aqi',
        'weather radar map', 'temperature', 'humidity', 'wind speed', 'sunrise sunset time',
        'moon phase', 'rain forecast', 'weather near me', 'free weather app', 'weather by city',
      ],
      alternates: { canonical: url },
      openGraph: {
        type: 'website',
        url,
        siteName: 'ToolNest',
        title,
        description,
        images: [{ url: og, width: 1200, height: 630, alt: 'World Weather Pro by ToolNest' }],
      },
      twitter: {
        card: 'summary_large_image',
        title,
        description,
        images: [og],
      },
    };
  }

  return toolMetadata(tool, cat);
}

function buildFaq(tool: Tool, cat?: Category): Faq[] {
  const slug = tool.slug;
  if (slug === 'pdf-converter') {
    return [
      { q: 'Is PDF Converter free?', a: 'Yes - unlimited conversions completely free. No signup required, no watermarks. All processing happens directly in your browser.' },
      { q: 'What formats can I convert?', a: 'PDF to Word, Excel, PowerPoint, JPG, PNG, TXT, HTML, Markdown, and CSV. Also convert DOCX, XLSX, images, TXT, HTML, and Markdown back to PDF.' },
      { q: 'Will my PDF layout be preserved?', a: 'For text-based PDFs, layout is preserved as closely as possible. For scanned PDFs, try our PDF OCR tool first for best results.' },
      { q: 'Is it safe to upload sensitive documents?', a: 'Your files never leave your device - all conversion runs 100% in your browser. Nothing is uploaded to any server.' },
      { q: 'What is the maximum file size?', a: 'Since processing is local, the limit depends on your device memory. Files up to several hundred MB work smoothly on modern devices.' },
      { q: 'Can I convert scanned PDFs?', a: 'Scanned (image-only) PDFs work best with our PDF OCR tool first, which extracts text using AI. Then convert the result to Word or other formats.' },
    ];
  }
  if (slug === 'pan-card-photo-resizer') {
    return [
      { q: 'What is the difference between NSDL and UTI PAN photo requirements?', a: 'NSDL (Protean) requires 197×276 px photo at 200 DPI (20–50 KB JPEG). UTIITSL requires 213×213 px at 300 DPI (max 30 KB). Signatures also differ: NSDL 354×157 px, UTI 400×200 px. Our tool auto-applies the correct specs when you select your portal.' },
      { q: 'Why does my PAN photo keep getting rejected?', a: 'The top reasons are wrong dimensions, file size over the KB limit, non-JPEG format (PNG/HEIC), dark or coloured background, and incorrect DPI metadata. ToolNest fixes all of these automatically with AI face crop, white background, force-weight compression, and embedded DPI.' },
      { q: 'What DPI is required for NSDL PAN card photo?', a: 'NSDL requires 200 DPI embedded in the JPEG file. UTI requires 300 DPI for photos and 600 DPI for signatures. Our tool embeds the correct DPI metadata on every download.' },
      { q: 'Can I use a selfie for PAN card application?', a: 'Yes, if it is front-facing with a neutral expression and plain white/light background. Use our camera capture with face guide, or upload a selfie and let AI remove the background and auto-crop to spec.' },
      { q: 'Is this PAN card resizer safe and private?', a: 'Yes — 100% browser-based processing. Your photo never leaves your device. No uploads to ToolNest servers. No account required. Unlimited free use.' },
      { q: 'Can CSC operators use batch mode?', a: 'Yes. Enable Batch Mode to process multiple photos or signatures with the same NSDL/UTI settings. Download each file individually or all at once as a ZIP.' },
      { q: 'Does it work on mobile phones?', a: 'Yes — fully responsive on Android and iPhone. Upload from gallery, capture from camera, pinch-to-zoom while editing, and download ready-to-upload JPEG files.' },
      { q: 'What signature size is required for PAN card?', a: 'NSDL: 354×157 px, 10–50 KB JPEG. UTI: 400×200 px, max 60 KB JPEG. Select Signature in step 2 and the tool applies exact dimensions automatically.' },
    ];
  }
  if (slug === 'image-compressor') {
    return [
      { q: 'How much can I compress my images?', a: 'ToolNest Image Compressor can reduce file size by up to 90% without visible quality loss. AVIF format achieves the best compression (50-70% smaller than JPEG), followed by WebP (25-35% smaller). Use our Compare Codecs tab to see exact results for your specific image.' },
      { q: 'What image formats are supported?', a: 'Input: JPEG, PNG, WebP, AVIF, GIF, BMP, TIFF, SVG, ICO, and HEIC/HEIF. Output: JPEG (MozJPEG), PNG (OxiPNG), WebP, AVIF (best compression), and JPEG XL (next-gen). Convert between any format while compressing in a single pass.' },
      { q: 'Is my data safe? Are images uploaded to a server?', a: 'Your images NEVER leave your device. All compression runs 100% in your browser using WebAssembly technology. No server uploads, no data collection, no accounts needed. Works offline after first load.' },
      { q: 'Can I compress images to a specific file size (e.g., 50KB for PAN card)?', a: 'Yes! Use Target Size mode to specify exact file size targets (10KB to 10MB). We also have pre-built Government/Exam presets for PAN Card (≤30KB), Aadhaar (≤100KB), Passport, SSC, UPSC, IBPS, and more — with exact dimensions and size limits auto-applied.' },
      { q: 'How many images can I compress at once?', a: 'Unlimited batch processing — compress 100+ images simultaneously. Our parallel processing engine uses Web Workers to compress multiple images at once without freezing your browser. Download all results as a single ZIP file.' },
      { q: 'What is AVIF and why should I use it?', a: 'AVIF is a next-generation image format (developed by Alliance for Open Media) that achieves 30-50% better compression than WebP and 50-70% better than JPEG at equivalent visual quality. It supports HDR, transparency, and animation. All modern browsers (Chrome, Firefox, Safari, Edge) support AVIF as of 2024+.' },
      { q: 'Can I generate responsive images for my website?', a: 'Yes! Use the Responsive Set tab to generate multiple sizes (150px to 2560px) from a single image. Downloads include srcset-ready filenames and we generate ready-to-use HTML picture/srcset code for your website.' },
      { q: 'How does the Compare Codecs feature work?', a: 'Compare Codecs compresses your image using JPEG, WebP, AVIF, and PNG simultaneously at the same quality level, then shows you the results side-by-side with exact file sizes, compression ratios, and processing times. Download whichever version works best for your needs.' },
      { q: 'Does it work on mobile phones?', a: 'Yes — fully responsive and works on any modern browser (Chrome, Safari, Firefox, Edge) on iOS, Android, and desktop. The WebAssembly compression engine runs efficiently even on mobile devices.' },
      { q: 'How is this different from TinyPNG or Squoosh?', a: 'ToolNest combines the best of both: Squoosh-level quality control (AVIF, WebP, manual settings, comparison slider) + TinyPNG-level batch processing (unlimited images) + features neither has: AI-powered auto-settings, target file size mode, social media presets, responsive image generation, government document presets, and compression reports — all in one tool, all 100% free and private.' },
    ];
  }
  if (slug === 'video-converter') {
    return [
      { q: 'What video formats can I convert?', a: 'Input: MP4, MKV, MOV, AVI, WMV, FLV, WebM, MPEG, 3GP, M4V, TS, MTS, GIF and more. Output: MP4 (H.264), WebM (VP9), MKV, MOV, AVI, GIF, or audio-only MP3, AAC, WAV, FLAC, OGG, M4A.' },
      { q: 'Is my video uploaded to a server?', a: 'No. All conversion runs 100% in your browser using FFmpeg WebAssembly. Your videos never leave your device — fully private, no account required.' },
      { q: 'What is the maximum file size?', a: 'Browser FFmpeg works best for files under ~200MB per video. Larger files may work depending on your device RAM. Batch mode processes videos one at a time to manage memory.' },
      { q: 'Can I convert videos for YouTube, Instagram or TikTok?', a: 'Yes! Use Social/Platform Presets for YouTube 1080p, YouTube Shorts, Instagram Reels, TikTok, LinkedIn, X/Twitter, and WhatsApp Status — dimensions, bitrate and format applied automatically.' },
      { q: 'Can I extract audio from a video?', a: 'Yes — set Output type to "Audio only" and choose MP3, AAC, WAV, FLAC, OGG or M4A. Optional loudness normalization included.' },
      { q: 'Does AI analysis really help?', a: 'AI Smart Analysis detects resolution, bitrate, duration, orientation and quality score, then suggests optimal format, resolution and compression mode before you convert.' },
      { q: 'Can I trim, rotate or change speed?', a: 'Yes — use Trim & Edit settings for start/end timestamps, 90° rotation, and speed from 0.5× to 2×. AI denoise, stabilization and upscale filters are also available.' },
      { q: 'Can I convert multiple videos at once?', a: 'Yes — unlimited batch upload with queue manager. Download individually or all results as a ZIP with performance report.' },
      { q: 'How is this better than CloudConvert or HandBrake?', a: 'ToolNest combines HandBrake-level codec control + CloudConvert-level format breadth + unique features: AI analysis, social presets, batch queue, performance report, and 100% private browser processing — no upload wait, no daily limits.' },
    ];
  }
  if (slug === 'audio-converter') {
    return [
      { q: 'What audio formats are supported?', a: 'Input: MP3, WAV, FLAC, AAC, M4A, OGG, OPUS, WMA, AIFF, AMR, AC3 and more. Output: MP3, WAV, FLAC, AAC, M4A, OGG, OPUS, AIFF, ALAC, AMR, AC3, PCM.' },
      { q: 'Is my audio uploaded to a server?', a: 'No — 100% browser processing with FFmpeg WebAssembly. Your files never leave your device.' },
      { q: 'What are the quality presets?', a: 'Balanced, Lossless, High Quality, Mobile, Streaming, Podcast Ready, and Studio Quality — each tuned for different use cases.' },
      { q: 'Does AI analysis help?', a: 'Yes — detects bitrate, loudness, clipping, noise, voice vs music, BPM, and suggests optimal format and enhancement settings.' },
      { q: 'Can I remove background noise?', a: 'Yes — enable AI Noise Removal, Voice Enhancement, Silence Removal, and Loudness Optimization in the AI Enhancement panel.' },
      { q: 'Can I record audio directly?', a: 'Yes — use Record Mic to capture from your microphone, then convert to any format.' },
      { q: 'Can I convert multiple files?', a: 'Yes — unlimited batch upload with queue manager. Download individually or as ZIP with full audio report.' },
      { q: 'Can I merge multiple tracks?', a: 'Yes — enable "Merge all files into one audio track" when you have 2+ files in the queue. FFmpeg concatenates then converts in one pass.' },
      { q: 'Does it have a waveform editor?', a: 'Yes — after analysis, drag trim handles on the interactive timeline to set start/end points. Spectrum analyzer shows frequency distribution.' },
      { q: 'Can I edit ID3 metadata and album art?', a: 'Yes — use Metadata & Album Art panel to set title, artist, album, genre, and embed cover images into MP3/M4A output.' },
    ];
  }
  if (slug === 'pdf-to-word') {
    return [
      { q: 'Is PDF to Word conversion free?', a: 'Yes — unlimited conversions, no signup, no watermarks. OCR and Indic AI repair are included free.' },
      { q: 'Will formatting be preserved?', a: 'Layout Exact mode preserves tables, fonts and structure. A confidence score shows how faithful the output is. Scanned PDFs use OCR automatically.' },
      { q: 'Does it work for Bengali and Hindi PDFs?', a: 'Yes — world-first Indic Unicode AI repair fixes broken Bengali/Hindi text from government PDFs. OCR supports ben+eng, hin+eng and more.' },
      { q: 'Are my files uploaded to a server?', a: 'No. Default Local Mode processes everything in your browser. Privacy Ledger shows zero network uploads.' },
      { q: 'Can I convert scanned PDFs?', a: 'Yes. OCR runs automatically when the text layer is weak. Use OCR Deep mode for full-page scan conversion.' },
      { q: 'Can I convert multiple PDFs?', a: 'Yes — batch upload up to 3 files (free tier). Download as individual DOCX files or a ZIP.' },
    ];
  }
  if (slug === 'compress-pdf') {
    return [
      { q: 'How much can I compress a PDF?', a: 'Typically 40–85% reduction for image-heavy PDFs. AI Analyze shows compression potential before you compress.' },
      { q: 'Which compression mode should I use?', a: 'Smart AI picks automatically. Use Email Ready for attachments under 5MB, Web for fast loading, or Lossless for text-only PDFs.' },
      { q: 'Will quality be affected?', a: 'High Quality and Print modes preserve readability. Maximum mode targets smallest size. Quality score is shown in the report.' },
      { q: 'Can I compress multiple PDFs at once?', a: 'Yes — batch upload, ZIP import, queue manager, and ZIP download for batch results.' },
      { q: 'Are password-protected PDFs supported?', a: 'Yes. Enter the owner password on upload and compression runs locally in your browser.' },
      { q: 'Is it safe for confidential documents?', a: '100% browser processing — files never leave your device. Auto-private, no server storage.' },
      { q: 'Can I compress to a specific file size?', a: 'Yes — enable Target file size and set KB (e.g. 200KB for Aadhaar UIDAI upload). AI binary-searches quality until the target is met.' },
    ];
  }
  if (slug === 'background-remover') {
    return [
      { q: 'Is the background remover free?', a: 'Yes — unlimited use, no signup, no watermarks on exports.' },
      { q: 'How accurate is the AI cutout?', a: 'Powered by imgly AI with smart hair refinement, edge decontamination and feather controls. Works on people, products, animals and logos.' },
      { q: 'Can I replace the background?', a: 'Yes — choose from 14 presets (studio, nature, gradient, transparent) or export transparent PNG for use anywhere.' },
      { q: 'Does it work on phone photos?', a: 'Yes — camera capture, paste from clipboard, and full mobile-responsive editor with touch brush.' },
      { q: 'Are my photos uploaded?', a: 'Never. AI runs 100% in your browser. First use downloads the model (~40MB), then it is cached.' },
      { q: 'Can I process multiple images?', a: 'Yes — batch upload, ZIP import, per-image editing, and ZIP download.' },
    ];
  }
  if (slug === 'merge-pdf') {
    return [
      { q: 'Is Merge PDF free?', a: 'Yes — unlimited merges, all 10 merge modes, AI organize included free.' },
      { q: 'How many PDFs can I merge?', a: 'Unlimited files in one session. Drag to reorder pages, exclude pages, and use AI to detect blanks and duplicates.' },
      { q: 'What are the merge modes?', a: 'Normal, Fast, Lossless, Compressed, PDF/A, Print, Book, PAN Card, Passport, and Certificate — each tuned for different outputs.' },
      { q: 'Are files uploaded to a server?', a: 'No — 100% browser processing. Your PDFs never leave your device.' },
    ];
  }
  if (slug === 'image-to-pdf') {
    return [
      { q: 'Is Image to PDF free?', a: 'Yes — unlimited images, batch convert, AI analysis, and all PDF settings included free.' },
      { q: 'What image formats are supported?', a: 'JPG, PNG, WEBP, HEIC, AVIF, BMP, GIF, TIFF, SVG and more. Paste from clipboard, import URL, ZIP, or camera capture.' },
      { q: 'Can I reorder images before converting?', a: 'Yes — drag-and-drop timeline, multi-select, rotate, duplicate, sort by name/date/size, and shuffle.' },
      { q: 'Does AI optimize my images?', a: 'AI analyzes blur, orientation, duplicates, documents, and quality score. Smart compression and auto-rotate are applied during conversion.' },
      { q: 'Are my files uploaded?', a: 'No — 100% browser processing with pdf-lib. Your images never leave your device.' },
    ];
  }
  if (slug === 'ai-chat') {
    return [
      { q: 'Is AI Chat free?', a: 'Yes — 10 free server messages/day. For unlimited free chat, add your own Gemini API key from aistudio.google.com (free, no credit card). Server uses Gemini 2.0 Flash or Llama 3.3 70B as fallback.' },
      { q: 'Is AI really free?', a: 'Yes — 100% free in your browser with no API key. ToolNest uses free Gemini Flash via browser AI. Optional: paste your own free Gemini key in AI Settings for unlimited speed.' },
      { q: 'Why did I see an error before?', a: 'Older versions used a blocked fallback. Now ToolNest auto-switches to free browser AI — no setup needed.' },
      { q: 'What AI model powers it?', a: 'Google Gemini (flash/pro). You can switch models in AI Settings. Streaming responses with markdown formatting.' },
      { q: 'What are the chat personas?', a: 'General, Code, Creative, Analyst, Teacher, and PDF Expert — each with tuned system prompts and suggested prompts.' },
      { q: 'Is chat history saved?', a: 'Yes — up to 50 chats saved locally in your browser. Export any chat as Markdown or JSON.' },
      { q: 'Can I attach documents?', a: 'Yes — attach PDF, TXT, MD, CSV, or HTML files for context-aware answers.' },
      { q: 'Are my conversations private?', a: 'Chat history stays in your browser localStorage. Server AI processes messages but does not store them permanently.' },
    ];
  }
  if (slug === 'ai-pdf-assistant') {
    return [
      { q: 'How does AI PDF Assistant work?', a: 'Upload a PDF, then ask questions. AI reads the document text and answers from its content only.' },
      { q: 'Does it work on scanned PDFs?', a: 'Best on text-based PDFs. For scanned documents, use PDF OCR first, then chat with the searchable PDF.' },
      { q: 'Is it free?', a: 'Yes — 100% free, no API key required. Same free AI as the header AI Assistant.' },
    ];
  }
  if (slug === 'world-weather-pro') {
    return [
      { q: 'Is World Weather Pro free to use?', a: 'Yes — 100% free with no signup, no API key and no limits. Search unlimited cities, view live conditions, hourly, 7-day and 14-day forecasts, air quality, radar maps and astronomy for free.' },
      { q: 'How accurate is the weather data?', a: 'Forecasts use high-resolution global weather models updated continuously, with current conditions, temperature, feels-like, humidity, wind, pressure, cloud cover and precipitation probability for any location worldwide.' },
      { q: 'Does it show my local weather automatically?', a: 'Yes. Allow location access and it detects your city via GPS for pinpoint accuracy. If GPS is off, it falls back to your approximate city by IP, so you still get local weather instantly.' },
      { q: 'What is the Air Quality Index (AQI) and which pollutants are shown?', a: 'The AQI rates how clean or polluted the air is. World Weather Pro shows the US AQI value and category (Good to Hazardous) plus PM2.5, PM10, ozone (O₃) and nitrogen dioxide (NO₂) levels, with a health recommendation.' },
      { q: 'Can I see an hourly and 14-day forecast?', a: 'Yes — a 48-hour hourly timeline with temperature and rain chance, plus 7-day and full 14-day forecasts showing highs, lows, conditions, rain probability and wind.' },
      { q: 'Does it have a live weather radar map?', a: 'Yes. The interactive map shows rain, wind, temperature, cloud and pressure layers you can switch between, so you can track incoming storms and precipitation in real time.' },
      { q: 'Can I switch between Celsius and Fahrenheit?', a: 'Yes — one tap in the header toggles the entire dashboard between °C and °F, including the hero, hourly, daily forecasts and favorite cities.' },
      { q: 'Does World Weather Pro show sunrise, sunset and moon phase?', a: 'Yes — the Astronomy view shows sunrise, sunset, solar noon, day length, golden hour, blue hour, plus the current moon phase and illumination percentage.' },
      { q: 'Can I save and compare multiple cities?', a: 'Yes. Add cities to your Favorite Cities rail for live temperatures at a glance, and use Compare Cities to view several locations side by side. Favorites stay in your browser only.' },
      { q: 'Is my location and data private?', a: 'Yes — your location and saved cities never leave your device. The app only requests the weather data it needs to display and stores nothing on any server.' },
    ];
  }
  if (slug === 'age-calculator') {
    return [
      { q: 'How accurate is the age calculation?', a: 'ToolNest uses calendar-accurate year/month/day breakdown with leap-year support. When live mode is on, hours, minutes and seconds tick in real time.' },
      { q: 'Is my date of birth stored?', a: 'No. All calculations run 100% in your browser. Nothing is sent to any server or saved to a database.' },
      { q: 'Can I calculate age on a future or past date?', a: 'Yes — turn off Live mode and pick any To date. Use Swap to reverse dates quickly.' },
      { q: 'What are the life statistics based on?', a: 'Heartbeats (~72 bpm), breaths (~16/min), sleep (~33% of life), and walking distance (~5 km/day) are estimates for fun — not medical advice.' },
      { q: 'Can I share my result?', a: 'Yes — copy text, download PDF/PNG, print, share a link with dates in the URL, or generate a QR code.' },
    ];
  }
  return defaultToolFaq(tool, cat);
}

function getTrustExtra(slug: string): string {
  if (slug === 'pdf-converter') return 'Files auto-deleted after 24h';
  if (slug === 'image-compressor') return '100% Private · No Upload';
  if (slug === 'video-converter') return 'FFmpeg WASM · AI Analysis · Batch';
  if (slug === 'audio-converter') return 'AI Analysis · Waveform · Spectrum · Merge';
  if (slug === 'pan-card-photo-resizer') return 'AI Face Crop · 12-Point Compliance';
  if (slug === 'pdf-to-word') return 'AI Indic Repair · Confidence Score';
  if (slug === 'compress-pdf') return 'AI Smart Modes · Batch Queue';
  if (slug === 'background-remover') return 'AI Hair Refine · 100% Private';
  if (slug === 'merge-pdf') return 'AI Organize · 10 Merge Modes';
  if (slug === 'image-to-pdf') return 'AI Analysis · Drag Timeline · Batch';
  if (slug === 'ai-chat') return '6 Personas · Chat History · Streaming';
  if (slug === 'ai-pdf-assistant') return 'PDF Q&A · Summarize · Extract';
  if (slug === 'age-calculator') return 'Live Ticking · Zodiac · Milestones · AI';
  if (slug === 'world-weather-pro') return 'Live · 14-Day · AQI · Radar · No Signup';
  return 'Runs in your browser';
}

export default async function ToolPage({ params }: Props) {
  const { tool: slug } = await params;
  const tool = getTool(slug);
  if (!tool) notFound();
  const cat = getCategory(tool.category);
  const related = getToolsByCategory(tool.category).filter((t) => t.slug !== tool.slug).slice(0, 5);
  const faq = buildFaq(tool, cat);
  const trustExtra = getTrustExtra(slug);

  const jsonLd = toolJsonLd(tool, cat, faq);

  return (
    <div className="container" style={{ paddingBottom: 64 }}>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      <nav className="breadcrumb" aria-label="Breadcrumb">
        <Link href="/">Home</Link> / <Link href={`/tools/${tool.category}`}>{cat?.name}</Link> / <span>{tool.name}</span>
      </nav>

      <div className="tool-header">
        <span className="tool-header-icon" style={{ background: `var(--${cat?.accent || 'brand-primary'})` }}>
          <Icon name={tool.icon} size={28} />
        </span>
        <div>
          <h1>{tool.name}</h1>
          <p>{tool.description}</p>
        </div>
      </div>
      <div className="trust-row">
        <ToolUsageStat slug={tool.slug} />
        <span>&middot;</span>
        <span>&#128274; 100% Secure &amp; Private</span>
        <span>&middot;</span>
        <span>&#9889; {trustExtra}</span>
      </div>

      <div className="tool-page-layout">
        <div className="tool-page-main">
          <div className="workspace glass">
            <ToolRunner tool={tool} />
          </div>
          {/* Ad 2 — below primary action (728×90 desktop) */}
          <ToolMidAd />
        </div>
        {/* Desktop right sidebar ad (300×250) */}
        <ToolSidebarAd />
      </div>

      <section className="hiw">
        {[
          { n: 1, t: tool.accept ? 'Upload' : 'Enter', d: tool.accept ? 'Drag & drop your file or click to browse - nothing is uploaded to any server.' : 'Fill in your input - everything stays on your device.' },
          { n: 2, t: 'Process', d: slug === 'pdf-converter' ? 'Pick your target format and options. Click Convert - processing is instant and local.' : 'Pick your options and click the action button. Processing is instant and local.' },
          { n: 3, t: 'Download', d: slug === 'pdf-converter' ? 'Download your converted file instantly. Convert to another format without re-uploading.' : 'Grab your result immediately. Run it again as many times as you like - free forever.' },
        ].map((s) => (
          <div key={s.n} className="hiw-step glass">
            <span className="hiw-num">{s.n}</span>
            <b>{s.t}</b>
            <p>{s.d}</p>
          </div>
        ))}
      </section>

      <section className="faq">
        <h2>Frequently Asked Questions</h2>
        {faq.map((f) => (
          <details key={f.q} className="faq-item">
            <summary>{f.q}</summary>
            <p>{f.a}</p>
          </details>
        ))}
      </section>

      {related.length > 0 && (
        <section className="related">
          <div className="related-head">
            <h2>Related {cat?.name}</h2>
            <ToolSmartlink />
          </div>
          <div className="tool-grid">
            {related.map((t) => <ToolCard key={t.slug} tool={t} />)}
          </div>
        </section>
      )}

      {/* Ad 3 — before footer (desktop 300×250, mobile 320×50) */}
      <ToolPreFooterAd />

      <FeatureStrip />
    </div>
  );
}
