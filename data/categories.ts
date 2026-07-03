export interface Category {
  slug: string;
  name: string;
  shortName: string;
  icon: string;
  accent: string; // CSS variable name
  description: string;
}

export const categories: Category[] = [
  { slug: 'pdf', name: 'PDF Tools', shortName: 'PDF', icon: 'file-text', accent: 'accent-pdf', description: 'Convert, merge, split, compress, protect and edit PDF files.' },
  { slug: 'image', name: 'Image Tools', shortName: 'Image', icon: 'image', accent: 'accent-image', description: 'Convert, compress, resize, crop and enhance images with AI.' },
  { slug: 'video', name: 'Video Tools', shortName: 'Video', icon: 'video', accent: 'accent-video', description: 'Convert, compress, trim, merge and edit videos in your browser.' },
  { slug: 'audio', name: 'Audio Tools', shortName: 'Audio', icon: 'music', accent: 'accent-audio', description: 'Convert, compress, cut and clean up audio files.' },
  { slug: 'ai', name: 'AI Tools', shortName: 'AI', icon: 'bot', accent: 'accent-ai', description: 'AI chat, writing, images, resumes, translation and more.' },
  { slug: 'developer', name: 'Developer Tools', shortName: 'Developer', icon: 'code', accent: 'accent-dev', description: 'JSON, Base64, JWT, UUID, hashing and API testing utilities.' },
  { slug: 'text', name: 'Text Tools', shortName: 'Text', icon: 'type', accent: 'accent-dev', description: 'Count, convert, compare, sort and transform text instantly.' },
  { slug: 'seo', name: 'SEO Tools', shortName: 'SEO', icon: 'search', accent: 'accent-seo', description: 'Meta tags, sitemaps, schema markup and on-page SEO analysis.' },
  { slug: 'business', name: 'Business Tools', shortName: 'Business', icon: 'briefcase', accent: 'accent-business', description: 'Invoices, receipts, quotations and business calculators.' },
  { slug: 'social', name: 'Social Media Tools', shortName: 'Social', icon: 'share', accent: 'accent-social', description: 'Thumbnails, captions, hashtags, bios and post generators.' },
  { slug: 'utility', name: 'Utility Tools', shortName: 'Utilities', icon: 'settings', accent: 'accent-utility', description: 'QR codes, barcodes, passwords, converters and more.' },
  { slug: 'security', name: 'Security Tools', shortName: 'Security', icon: 'shield', accent: 'accent-security', description: 'Hashes, checksums, SSL checks and encryption.' },
  { slug: 'calculator', name: 'Calculator Tools', shortName: 'Calculators', icon: 'calculator', accent: 'accent-calculator', description: 'Age, BMI, percentage, EMI, discount and scientific calculators.' },
  { slug: 'file-converter', name: 'File Converter Tools', shortName: 'Converter', icon: 'repeat', accent: 'accent-file', description: 'ZIP, CSV, Excel, XML and JSON conversion tools.' },
  { slug: 'government', name: 'Government Tools', shortName: 'Government', icon: 'landmark', accent: 'accent-gov', description: 'Passport, PAN, Aadhaar and exam photo/signature resizers.' },
];

export function getCategory(slug: string): Category | undefined {
  return categories.find((c) => c.slug === slug);
}

/** Sidebar entries exactly as in the approved homepage mockup. */
export interface SidebarEntry {
  slug: string; // '' = all tools
  label: string;
  icon: string;
  count: string;
  badge?: 'new';
}

export const sidebarEntries: SidebarEntry[] = [
  { slug: '', label: 'All Tools', icon: 'grid', count: '120+' },
  { slug: 'pdf', label: 'PDF Tools', icon: 'file-text', count: '20+' },
  { slug: 'image', label: 'Image Tools', icon: 'image', count: '25+' },
  { slug: 'video', label: 'Video Tools', icon: 'video', count: '20+' },
  { slug: 'audio', label: 'Audio Tools', icon: 'music', count: '15+' },
  { slug: 'ai', label: 'AI Tools', icon: 'bot', count: '30+', badge: 'new' },
  { slug: 'developer', label: 'Developer Tools', icon: 'code', count: '25+' },
  { slug: 'text', label: 'Text Tools', icon: 'type', count: '15+' },
  { slug: 'seo', label: 'SEO Tools', icon: 'search', count: '20+' },
  { slug: 'business', label: 'Business Tools', icon: 'briefcase', count: '15+' },
  { slug: 'file-converter', label: 'Converter Tools', icon: 'repeat', count: '20+' },
  { slug: 'utility', label: 'Utilities', icon: 'settings', count: '20+' },
  { slug: 'security', label: 'Security Tools', icon: 'shield', count: '10+' },
  { slug: 'calculator', label: 'Productivity', icon: 'zap', count: '15+' },
  { slug: 'government', label: 'File Tools', icon: 'folder', count: '15+' },
  { slug: 'social', label: 'Data Tools', icon: 'database', count: '15+' },
];
