'use client';

/**
 * AI-Powered Image Analysis Engine
 * Uses Gemini Vision to detect content type and recommend optimal compression settings.
 * Falls back to heuristic analysis when API key is not available.
 */

import { getApiKey, getModel } from '@/lib/ai';
import type { ImageAnalysis, OutputFormat, CompressionMode } from './image-compression-engine';

export interface AIAnalysisResult {
  contentType: 'photograph' | 'screenshot' | 'illustration' | 'text-heavy' | 'product' | 'landscape' | 'portrait' | 'graphic';
  hasFaces: boolean;
  hasText: boolean;
  complexity: 'low' | 'medium' | 'high';
  recommendedFormat: OutputFormat;
  recommendedQuality: number;
  recommendedMode: CompressionMode;
  explanation: string;
  confidence: number;
}

async function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      resolve(result.split(',')[1]);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

export async function analyzeImageWithAI(file: File): Promise<AIAnalysisResult> {
  const apiKey = getApiKey();

  if (!apiKey) {
    return heuristicAnalysis(file);
  }

  try {
    const base64 = await fileToBase64(file);
    const model = getModel();

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              {
                inlineData: {
                  mimeType: file.type,
                  data: base64,
                },
              },
              {
                text: `Analyze this image for compression optimization. Respond ONLY with valid JSON (no markdown, no code fences):
{
  "contentType": "photograph|screenshot|illustration|text-heavy|product|landscape|portrait|graphic",
  "hasFaces": true/false,
  "hasText": true/false,
  "complexity": "low|medium|high",
  "recommendedFormat": "avif|webp|jpeg|png",
  "recommendedQuality": 1-100,
  "explanation": "Brief reason for recommendation"
}

Rules:
- For photographs/landscapes: recommend avif at quality 65-75
- For screenshots/text-heavy: recommend png (lossless) or webp at quality 90+
- For illustrations/graphics with few colors: recommend png
- For product photos: recommend webp at quality 80-85
- For portraits with faces: recommend avif/webp at quality 75+ (preserve facial detail)
- Higher complexity = higher quality needed`,
              },
            ],
          }],
        }),
      },
    );

    if (!response.ok) {
      return heuristicAnalysis(file);
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';

    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return heuristicAnalysis(file);

    const parsed = JSON.parse(jsonMatch[0]);

    return {
      contentType: parsed.contentType || 'photograph',
      hasFaces: parsed.hasFaces ?? false,
      hasText: parsed.hasText ?? false,
      complexity: parsed.complexity || 'medium',
      recommendedFormat: parsed.recommendedFormat || 'webp',
      recommendedQuality: parsed.recommendedQuality || 75,
      recommendedMode: 'custom',
      explanation: parsed.explanation || 'AI-recommended settings for this image type.',
      confidence: 0.9,
    };
  } catch {
    return heuristicAnalysis(file);
  }
}

function heuristicAnalysis(file: File): AIAnalysisResult {
  const isJpeg = file.type === 'image/jpeg';
  const isPng = file.type === 'image/png';
  const isLarge = file.size > 1024 * 1024;

  if (isPng && !isLarge) {
    return {
      contentType: 'graphic',
      hasFaces: false,
      hasText: false,
      complexity: 'low',
      recommendedFormat: 'webp',
      recommendedQuality: 85,
      recommendedMode: 'balanced',
      explanation: 'PNG detected — WebP offers 25-35% better compression for graphics while preserving transparency.',
      confidence: 0.6,
    };
  }

  if (isPng && isLarge) {
    return {
      contentType: 'screenshot',
      hasFaces: false,
      hasText: true,
      complexity: 'medium',
      recommendedFormat: 'webp',
      recommendedQuality: 90,
      recommendedMode: 'balanced',
      explanation: 'Large PNG likely a screenshot — WebP at high quality preserves text sharpness while reducing size significantly.',
      confidence: 0.5,
    };
  }

  if (isJpeg && isLarge) {
    return {
      contentType: 'photograph',
      hasFaces: false,
      hasText: false,
      complexity: 'high',
      recommendedFormat: 'avif',
      recommendedQuality: 72,
      recommendedMode: 'balanced',
      explanation: 'Large JPEG photo — AVIF achieves 50-70% smaller files than JPEG at equivalent visual quality.',
      confidence: 0.7,
    };
  }

  return {
    contentType: 'photograph',
    hasFaces: false,
    hasText: false,
    complexity: 'medium',
    recommendedFormat: 'webp',
    recommendedQuality: 78,
    recommendedMode: 'balanced',
    explanation: 'General image — WebP provides reliable compression with broad browser support.',
    confidence: 0.5,
  };
}

export function getSmartCompressionSettings(
  analysis: AIAnalysisResult,
  basicAnalysis: ImageAnalysis,
): { format: OutputFormat; quality: number; effort: number } {
  let quality = analysis.recommendedQuality;

  if (analysis.hasFaces) {
    quality = Math.max(quality, 78);
  }
  if (analysis.hasText) {
    quality = Math.max(quality, 88);
  }
  if (analysis.complexity === 'high') {
    quality = Math.min(quality + 5, 95);
  }

  if (basicAnalysis.hasAlpha && analysis.recommendedFormat === 'jpeg') {
    return { format: 'webp', quality, effort: 6 };
  }

  return {
    format: analysis.recommendedFormat,
    quality,
    effort: analysis.complexity === 'high' ? 7 : 5,
  };
}
