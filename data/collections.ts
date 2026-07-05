/** Curated tool collections ("kits") shown on the All Tools page. */

export interface ToolCollection {
  slug: string;
  name: string;
  icon: string;
  description: string;
  tools: string[]; // tool slugs
  accent: string;  // CSS var name
}

export const collections: ToolCollection[] = [
  {
    slug: 'pan-card-kit',
    name: 'PAN Card Kit',
    icon: 'file-text',
    description: 'Photo, signature & document — NSDL/UTI compliant in minutes',
    tools: ['pan-card-photo-resizer', 'passport-photo-maker', 'aadhaar-pdf-compressor', 'merge-pdf'],
    accent: 'accent-pdf',
  },
  {
    slug: 'job-application-kit',
    name: 'Job Application Kit',
    icon: 'briefcase',
    description: 'Resume, photo, documents — application-ready package',
    tools: ['ai-resume-builder', 'exam-photo-signature-resizer', 'compress-pdf', 'merge-pdf'],
    accent: 'accent-business',
  },
  {
    slug: 'student-kit',
    name: 'Student Kit',
    icon: 'type',
    description: 'Notes, summaries, scans and submissions',
    tools: ['ai-summarizer', 'pdf-ocr', 'image-to-pdf', 'word-counter'],
    accent: 'accent-ai',
  },
  {
    slug: 'creator-kit',
    name: 'Creator Kit',
    icon: 'video',
    description: 'Thumbnails, compression, captions & hashtags',
    tools: ['youtube-thumbnail-maker', 'image-compressor', 'video-compressor', 'hashtag-generator'],
    accent: 'accent-video',
  },
];
