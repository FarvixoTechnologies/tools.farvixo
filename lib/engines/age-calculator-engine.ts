'use client';

import { aiComplete } from '@/lib/ai';

/* ─── Age Calculator Pro — client-side engine (no backend) ─────────────── */

const MS = 1;
const SEC = 1000 * MS;
const MIN = 60 * SEC;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;
const AVG_LIFE_YEARS = 73;

export interface AgeBreakdown {
  years: number;
  months: number;
  days: number;
  label: string;
}

export interface AgeTotals {
  milliseconds: number;
  seconds: number;
  minutes: number;
  hours: number;
  days: number;
  weeks: number;
  months: number;
  years: number;
}

export interface BirthdayInfo {
  nextDate: Date;
  daysRemaining: number;
  hoursRemaining: number;
  minutesRemaining: number;
  secondsRemaining: number;
  weekday: string;
  progressPct: number;
  isToday: boolean;
  ageTurning: number;
}

export interface AstrologyInfo {
  westernZodiac: string;
  westernSymbol: string;
  chineseZodiac: string;
  chineseEmoji: string;
  birthstone: string;
  birthFlower: string;
  luckyNumber: number;
  luckyColor: string;
  zodiacColor: string;
  zodiacGradient: string;
}

export interface Milestone {
  label: string;
  date: Date;
  reached: boolean;
  daysUntil?: number;
}

export interface LifeStats {
  lifePct: number;
  remainingYears: number;
  leapYearsLived: number;
  heartbeats: number;
  breaths: number;
  sleepHours: number;
  walkingKm: number;
  generation: string;
  decade: string;
}

export interface AgeResult {
  dob: Date;
  toDate: Date;
  isFuture: boolean;
  breakdown: AgeBreakdown;
  totals: AgeTotals;
  birthday: BirthdayInfo;
  astrology: AstrologyInfo;
  milestones: Milestone[];
  stats: LifeStats;
  nextMilestone: Milestone | null;
}

export const ZODIAC_THEME: Record<string, { symbol: string; color: string; gradient: string }> = {
  Aries: { symbol: '♈', color: '#ef4444', gradient: 'linear-gradient(135deg,#ef4444,#f97316)' },
  Taurus: { symbol: '♉', color: '#22c55e', gradient: 'linear-gradient(135deg,#22c55e,#84cc16)' },
  Gemini: { symbol: '♊', color: '#eab308', gradient: 'linear-gradient(135deg,#eab308,#facc15)' },
  Cancer: { symbol: '♋', color: '#60a5fa', gradient: 'linear-gradient(135deg,#3b82f6,#60a5fa)' },
  Leo: { symbol: '♌', color: '#f97316', gradient: 'linear-gradient(135deg,#f97316,#fbbf24)' },
  Virgo: { symbol: '♍', color: '#84cc16', gradient: 'linear-gradient(135deg,#65a30d,#84cc16)' },
  Libra: { symbol: '♎', color: '#ec4899', gradient: 'linear-gradient(135deg,#ec4899,#f472b6)' },
  Scorpio: { symbol: '♏', color: '#a855f7', gradient: 'linear-gradient(135deg,#6c4dff,#a855f7)' },
  Sagittarius: { symbol: '♐', color: '#8570ff', gradient: 'linear-gradient(135deg,#6366f1,#8570ff)' },
  Capricorn: { symbol: '♑', color: '#64748b', gradient: 'linear-gradient(135deg,#475569,#64748b)' },
  Aquarius: { symbol: '♒', color: '#06b6d4', gradient: 'linear-gradient(135deg,#0891b2,#06b6d4)' },
  Pisces: { symbol: '♓', color: '#14b8a6', gradient: 'linear-gradient(135deg,#0d9488,#14b8a6)' },
};

export const STAT_THEMES = [
  { icon: '📅', accent: '#6c4dff', bg: 'rgba(108,77,255,0.15)' },
  { icon: '🗓️', accent: '#ec4899', bg: 'rgba(236,72,153,0.15)' },
  { icon: '📆', accent: '#06b6d4', bg: 'rgba(6,182,212,0.15)' },
  { icon: '☀️', accent: '#f97316', bg: 'rgba(249,115,22,0.15)' },
  { icon: '⏰', accent: '#eab308', bg: 'rgba(234,179,8,0.15)' },
  { icon: '⏱️', accent: '#22c55e', bg: 'rgba(34,197,94,0.15)' },
  { icon: '⚡', accent: '#ef4444', bg: 'rgba(239,68,68,0.15)' },
  { icon: '✨', accent: '#8570ff', bg: 'rgba(139,92,246,0.15)' },
  { icon: '🌙', accent: '#3b82f6', bg: 'rgba(59,130,246,0.15)' },
];

export const TAB_META: Record<string, { icon: string; color: string }> = {
  results: { icon: '📊', color: '#6c4dff' },
  birthday: { icon: '🎂', color: '#f97316' },
  astrology: { icon: '✨', color: '#ec4899' },
  milestones: { icon: '🏁', color: '#22c55e' },
  stats: { icon: '💓', color: '#ef4444' },
  ai: { icon: '🤖', color: '#06b6d4' },
};

const CHINESE_EMOJI: Record<string, string> = {
  Rat: '🐀', Ox: '🐂', Tiger: '🐯', Rabbit: '🐰', Dragon: '🐉', Snake: '🐍',
  Horse: '🐴', Goat: '🐐', Monkey: '🐵', Rooster: '🐓', Dog: '🐕', Pig: '🐷',
};

function westernZodiac(d: Date): { sign: string; symbol: string } {
  const m = d.getMonth() + 1;
  const day = d.getDate();
  const v = m * 100 + day;
  if (v >= 321 && v <= 419) return { sign: 'Aries', symbol: '♈' };
  if (v >= 420 && v <= 520) return { sign: 'Taurus', symbol: '♉' };
  if (v >= 521 && v <= 620) return { sign: 'Gemini', symbol: '♊' };
  if (v >= 621 && v <= 722) return { sign: 'Cancer', symbol: '♋' };
  if (v >= 723 && v <= 822) return { sign: 'Leo', symbol: '♌' };
  if (v >= 823 && v <= 922) return { sign: 'Virgo', symbol: '♍' };
  if (v >= 923 && v <= 1022) return { sign: 'Libra', symbol: '♎' };
  if (v >= 1023 && v <= 1121) return { sign: 'Scorpio', symbol: '♏' };
  if (v >= 1122 && v <= 1221) return { sign: 'Sagittarius', symbol: '♐' };
  if (v >= 1222 || v <= 119) return { sign: 'Capricorn', symbol: '♑' };
  if (v >= 120 && v <= 218) return { sign: 'Aquarius', symbol: '♒' };
  if (v >= 219 && v <= 320) return { sign: 'Pisces', symbol: '♓' };
  return { sign: 'Pisces', symbol: '♓' };
}

const CHINESE = ['Rat', 'Ox', 'Tiger', 'Rabbit', 'Dragon', 'Snake', 'Horse', 'Goat', 'Monkey', 'Rooster', 'Dog', 'Pig'];

const BIRTHSTONES = ['Garnet', 'Amethyst', 'Aquamarine', 'Diamond', 'Emerald', 'Pearl', 'Ruby', 'Peridot', 'Sapphire', 'Opal', 'Topaz', 'Turquoise'];
const BIRTHFLOWERS = ['Carnation', 'Violet', 'Daffodil', 'Daisy', 'Lily of the Valley', 'Rose', 'Larkspur', 'Gladiolus', 'Aster', 'Marigold', 'Chrysanthemum', 'Narcissus'];
const LUCKY_COLORS = ['Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Indigo', 'Violet', 'Gold', 'Silver', 'Pink', 'Teal', 'Crimson'];

const MILESTONE_DEFS: { label: string; ms: number; icon: string }[] = [
  { label: 'First Minute', ms: MIN, icon: '⏱️' },
  { label: 'First Hour', ms: HOUR, icon: '🕐' },
  { label: 'First Day', ms: DAY, icon: '🌅' },
  { label: 'First Week', ms: WEEK, icon: '📅' },
  { label: 'First Month', ms: 30 * DAY, icon: '🌙' },
  { label: 'First Year', ms: 365 * DAY, icon: '🎂' },
  { label: '5 Years', ms: 5 * 365 * DAY, icon: '🎈' },
  { label: '10 Years', ms: 10 * 365 * DAY, icon: '🎉' },
  { label: '18 Years', ms: 18 * 365 * DAY, icon: '🔑' },
  { label: '21 Years', ms: 21 * 365 * DAY, icon: '🥂' },
  { label: '25 Years', ms: 25 * 365 * DAY, icon: '💎' },
  { label: '30 Years', ms: 30 * 365 * DAY, icon: '🌟' },
  { label: '40 Years', ms: 40 * 365 * DAY, icon: '🏆' },
  { label: '50 Years', ms: 50 * 365 * DAY, icon: '👑' },
  { label: '60 Years', ms: 60 * 365 * DAY, icon: '🎖️' },
  { label: '75 Years', ms: 75 * 365 * DAY, icon: '🌺' },
  { label: '100 Years', ms: 100 * 365 * DAY, icon: '💯' },
];

export function getMilestoneIcon(label: string): string {
  return MILESTONE_DEFS.find((m) => m.label === label)?.icon ?? '⭐';
}

function getGeneration(year: number): string {
  if (year >= 2013) return 'Gen Alpha';
  if (year >= 1997) return 'Gen Z';
  if (year >= 1981) return 'Millennial';
  if (year >= 1965) return 'Gen X';
  if (year >= 1946) return 'Baby Boomer';
  return 'Silent Generation';
}

function getDecade(year: number): string {
  return `${Math.floor(year / 10) * 10}s kid`;
}

export function parseDateInput(value: string, time = '00:00'): Date | null {
  if (!value) return null;
  const d = new Date(`${value}T${time || '00:00'}:00`);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function toDateInput(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function toTimeInput(d: Date): string {
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function diffCalendar(from: Date, to: Date): AgeBreakdown {
  const a = from <= to ? from : to;
  const b = from <= to ? to : from;
  let years = b.getFullYear() - a.getFullYear();
  let months = b.getMonth() - a.getMonth();
  let days = b.getDate() - a.getDate();
  if (days < 0) {
    months--;
    days += new Date(b.getFullYear(), b.getMonth(), 0).getDate();
  }
  if (months < 0) {
    years--;
    months += 12;
  }
  return {
    years,
    months,
    days,
    label: `${years} years, ${months} months, ${days} days`,
  };
}

function countLeapYears(from: Date, to: Date): number {
  const start = Math.min(from.getFullYear(), to.getFullYear());
  const end = Math.max(from.getFullYear(), to.getFullYear());
  let count = 0;
  for (let y = start; y <= end; y++) {
    if (isLeapYear(y)) count++;
  }
  return count;
}

export function isLeapYear(y: number): boolean {
  return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

function chineseZodiac(year: number): string {
  const animals = CHINESE;
  return animals[((year - 4) % 12 + 12) % 12];
}

function luckyFromDob(d: Date): { number: number; color: string } {
  const seed = d.getDate() + d.getMonth() * 31 + d.getFullYear();
  return {
    number: (seed % 9) + 1,
    color: LUCKY_COLORS[seed % LUCKY_COLORS.length],
  };
}

function nextBirthday(dob: Date, from: Date): BirthdayInfo {
  let next = new Date(from.getFullYear(), dob.getMonth(), dob.getDate(), dob.getHours(), dob.getMinutes(), dob.getSeconds());
  if (next <= from) next = new Date(from.getFullYear() + 1, dob.getMonth(), dob.getDate(), dob.getHours(), dob.getMinutes(), dob.getSeconds());
  const msUntil = next.getTime() - from.getTime();
  const daysRemaining = Math.floor(msUntil / DAY);
  const hoursRemaining = Math.floor((msUntil % DAY) / HOUR);
  const lastBday = new Date(from.getFullYear(), dob.getMonth(), dob.getDate());
  if (lastBday > from) lastBday.setFullYear(from.getFullYear() - 1);
  const yearMs = next.getTime() - lastBday.getTime();
  const elapsed = from.getTime() - lastBday.getTime();
  const progressPct = yearMs > 0 ? Math.min(100, (elapsed / yearMs) * 100) : 0;
  const ageTurning = next.getFullYear() - dob.getFullYear();
  const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return {
    nextDate: next,
    daysRemaining,
    hoursRemaining,
    minutesRemaining: Math.floor((msUntil % HOUR) / MIN),
    secondsRemaining: Math.floor((msUntil % MIN) / SEC),
    weekday: weekdays[next.getDay()],
    progressPct,
    isToday: from.getMonth() === dob.getMonth() && from.getDate() === dob.getDate(),
    ageTurning,
  };
}

function buildMilestones(dob: Date, to: Date): Milestone[] {
  const elapsed = to.getTime() - dob.getTime();
  return MILESTONE_DEFS.map((m) => {
    const date = new Date(dob.getTime() + m.ms);
    const reached = elapsed >= m.ms;
    return {
      label: m.label,
      date,
      reached,
      daysUntil: reached ? undefined : Math.ceil((m.ms - elapsed) / DAY),
    };
  });
}

export function calculateAge(dob: Date, toDate: Date): AgeResult | null {
  if (Number.isNaN(dob.getTime()) || Number.isNaN(toDate.getTime())) return null;
  const isFuture = dob > toDate;
  const start = isFuture ? toDate : dob;
  const end = isFuture ? dob : toDate;
  const ms = end.getTime() - start.getTime();
  if (ms < 0) return null;

  const breakdown = diffCalendar(start, end);
  const totals: AgeTotals = {
    milliseconds: ms,
    seconds: Math.floor(ms / SEC),
    minutes: Math.floor(ms / MIN),
    hours: Math.floor(ms / HOUR),
    days: Math.floor(ms / DAY),
    weeks: Math.floor(ms / WEEK),
    months: breakdown.years * 12 + breakdown.months,
    years: breakdown.years + breakdown.months / 12 + breakdown.days / 365.25,
  };

  const zodiac = westernZodiac(dob);
  const theme = ZODIAC_THEME[zodiac.sign] ?? ZODIAC_THEME.Aries;
  const chinese = chineseZodiac(dob.getFullYear());
  const lucky = luckyFromDob(dob);
  const milestones = buildMilestones(dob, toDate);
  const astrology: AstrologyInfo = {
    westernZodiac: zodiac.sign,
    westernSymbol: theme.symbol,
    chineseZodiac: chinese,
    chineseEmoji: CHINESE_EMOJI[chinese] ?? '🐉',
    birthstone: BIRTHSTONES[dob.getMonth()],
    birthFlower: BIRTHFLOWERS[dob.getMonth()],
    luckyNumber: lucky.number,
    luckyColor: lucky.color,
    zodiacColor: theme.color,
    zodiacGradient: theme.gradient,
  };

  const livedYears = totals.years;
  const stats: LifeStats = {
    lifePct: Math.min(100, (livedYears / AVG_LIFE_YEARS) * 100),
    remainingYears: Math.max(0, AVG_LIFE_YEARS - livedYears),
    leapYearsLived: countLeapYears(dob, toDate),
    heartbeats: Math.floor(totals.minutes * 72),
    breaths: Math.floor(totals.minutes * 16),
    sleepHours: Math.floor(totals.hours * 0.33),
    walkingKm: Math.round(totals.days * 5),
    generation: getGeneration(dob.getFullYear()),
    decade: getDecade(dob.getFullYear()),
  };

  return {
    dob,
    toDate,
    isFuture,
    breakdown,
    totals,
    birthday: nextBirthday(dob, toDate),
    astrology,
    milestones,
    nextMilestone: milestones.find((m) => !m.reached) ?? null,
    stats,
  };
}

export function formatNumber(n: number): string {
  return n.toLocaleString('en-US');
}

export function formatDate(d: Date): string {
  return d.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
}

export function formatDateTime(d: Date): string {
  return d.toLocaleString('en-US', {
    weekday: 'short', year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

export function buildReportText(r: AgeResult): string {
  const lines = [
    '═══ Age Calculator Pro — Farvixo Tools ═══',
    '',
    `Date of Birth: ${formatDateTime(r.dob)}`,
    `Calculated To: ${formatDateTime(r.toDate)}`,
    '',
    `Exact Age: ${r.breakdown.label}`,
    `Total Days: ${formatNumber(r.totals.days)}`,
    `Total Weeks: ${formatNumber(r.totals.weeks)}`,
    `Total Hours: ${formatNumber(r.totals.hours)}`,
    `Total Minutes: ${formatNumber(r.totals.minutes)}`,
    `Total Seconds: ${formatNumber(r.totals.seconds)}`,
  ];
  if (!r.isFuture) {
    lines.push(
      '',
      `Next Birthday: ${formatDate(r.birthday.nextDate)} (${r.birthday.daysRemaining} days)`,
      `Turning: ${r.birthday.ageTurning} years old`,
      '',
      `Zodiac: ${r.astrology.westernSymbol} ${r.astrology.westernZodiac}`,
      `Chinese Zodiac: ${r.astrology.chineseZodiac}`,
      `Birthstone: ${r.astrology.birthstone}`,
      `Birth Flower: ${r.astrology.birthFlower}`,
      '',
      `Life Progress: ${r.stats.lifePct.toFixed(1)}% (avg ${AVG_LIFE_YEARS}yr expectancy)`,
      `Heartbeats (est.): ${formatNumber(r.stats.heartbeats)}`,
      `Breaths (est.): ${formatNumber(r.stats.breaths)}`,
      `Sleep (est.): ${formatNumber(r.stats.sleepHours)} hours`,
      `Walking (est.): ${formatNumber(r.stats.walkingKm)} km`,
    );
  }
  lines.push('', 'Generated at tools.farvixo.com/tools/calculator/age-calculator');
  return lines.join('\n');
}

export function buildShareUrl(dob: string, to: string, dobTime?: string, toTime?: string): string {
  if (typeof window === 'undefined') return '';
  const params = new URLSearchParams({ dob, to });
  if (dobTime) params.set('dobTime', dobTime);
  if (toTime) params.set('toTime', toTime);
  return `${window.location.origin}${window.location.pathname}?${params}`;
}

export async function generateAiSummary(r: AgeResult, type: 'summary' | 'health' | 'wishes' | 'facts' | 'motivation' = 'summary'): Promise<string> {
  const payload = {
    age: r.breakdown.label,
    days: r.totals.days,
    zodiac: r.astrology.westernZodiac,
    birthdayIn: r.birthday.daysRemaining,
    lifePct: r.stats.lifePct.toFixed(1),
  };
  const prompts: Record<string, string> = {
    summary: `Write a warm 2-sentence age summary. Data: ${JSON.stringify(payload)}`,
    health: `Give 3 short health tips for someone who is ${r.breakdown.label} old. Bullet points, plain text.`,
    wishes: `Write a cheerful birthday wish for someone turning ${r.birthday.ageTurning} in ${r.birthday.daysRemaining} days. 1-2 sentences.`,
    facts: `Share 2 fun facts about being ${r.breakdown.years} years old or born in ${r.dob.getFullYear()}. Plain text.`,
    motivation: `One inspiring daily motivation line for someone ${r.breakdown.label} old. No clichés.`,
  };
  try {
    return await aiComplete(
      [{ role: 'user', content: prompts[type] }],
      'You are a friendly assistant. Be concise, no markdown, no hashtags.',
    );
  } catch {
    return `You are ${r.breakdown.label} young! ${r.birthday.daysRemaining} days until your next birthday.`;
  }
}

export const POPULAR_DOB = [
  { label: '2000', dob: '2000-01-01', color: '#6c4dff' },
  { label: '1995', dob: '1995-06-15', color: '#ec4899' },
  { label: '1990', dob: '1990-03-20', color: '#06b6d4' },
  { label: '2010', dob: '2010-07-04', color: '#22c55e' },
  { label: '1985', dob: '1985-12-25', color: '#f97316' },
  { label: '2020', dob: '2020-01-01', color: '#eab308' },
];
