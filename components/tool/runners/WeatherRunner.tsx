'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Icon from '@/components/Icon';
import {
  type WeatherBundle,
  type WeatherLocation,
  type WeatherIconKey,
  searchLocations,
  fetchWeatherBundle,
  detectGpsLocation,
  generateWeatherSummary,
  generateClothingAdvice,
  outdoorScore,
  getFavorites,
  getRecents,
  toggleFavorite,
  isFavorite,
  addRecent,
  bgPreset,
  windDirLabel,
} from '@/lib/engines/weather-engine';

type Tab = 'overview' | 'hourly' | 'daily' | 'aqi' | 'astro' | 'ai';

const WEATHER_EMOJI: Record<WeatherIconKey, string> = {
  clear: '☀️',
  partly: '⛅',
  cloudy: '☁️',
  fog: '🌫️',
  rain: '🌧️',
  snow: '❄️',
  storm: '⛈️',
  night: '🌙',
};

const QUICK_CITIES = ['London', 'New York', 'Tokyo', 'Dhaka', 'Dubai', 'Sydney'];

function formatHour(iso: string): string {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function formatDay(date: string): string {
  return new Date(date + 'T12:00:00').toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' });
}

function aqiColor(aqi: number): string {
  if (aqi <= 50) return 'var(--success-green)';
  if (aqi <= 100) return '#eab308';
  if (aqi <= 150) return '#f97316';
  if (aqi <= 200) return '#ef4444';
  return '#991b1b';
}

export default function WeatherRunner() {
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState<WeatherLocation[]>([]);
  const [searchOpen, setSearchOpen] = useState(false);
  const [bundle, setBundle] = useState<WeatherBundle | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [tab, setTab] = useState<Tab>('overview');
  const [favorites, setFavorites] = useState<WeatherLocation[]>([]);
  const [recents, setRecents] = useState<WeatherLocation[]>([]);
  const [fav, setFav] = useState(false);
  const [aiSummary, setAiSummary] = useState('');
  const [aiLoading, setAiLoading] = useState(false);
  const [localTime, setLocalTime] = useState('');
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const searchRef = useRef<HTMLDivElement>(null);

  const loadLocation = useCallback(async (loc: WeatherLocation) => {
    setLoading(true);
    setError('');
    setSearchOpen(false);
    setQuery('');
    setSuggestions([]);
    setAiSummary('');
    try {
      const data = await fetchWeatherBundle(loc);
      setBundle(data);
      addRecent(loc);
      setRecents(getRecents());
      setFav(isFavorite(loc.slug));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load weather');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    setFavorites(getFavorites());
    setRecents(getRecents());
    void detectGpsLocation()
      .then(loadLocation)
      .catch(() => { /* user can search manually */ });
  }, [loadLocation]);

  useEffect(() => {
    if (!bundle?.location.timezone) return;
    const tick = () => {
      setLocalTime(
        new Date().toLocaleTimeString('en-US', {
          timeZone: bundle.location.timezone,
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
        }),
      );
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [bundle?.location.timezone]);

  useEffect(() => {
    if (!query.trim()) {
      setSuggestions([]);
      return;
    }
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      try {
        const results = await searchLocations(query);
        setSuggestions(results);
        setSearchOpen(true);
      } catch {
        setSuggestions([]);
      }
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setSearchOpen(false);
      }
    };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, []);

  const handleFavorite = () => {
    if (!bundle) return;
    const next = toggleFavorite(bundle.location);
    setFavorites(next);
    setFav(isFavorite(bundle.location.slug));
  };

  const loadAi = async () => {
    if (!bundle || aiSummary) return;
    setAiLoading(true);
    try {
      const text = await generateWeatherSummary(bundle);
      setAiSummary(text);
    } finally {
      setAiLoading(false);
    }
  };

  useEffect(() => {
    if (tab === 'ai' && bundle && !aiSummary && !aiLoading) void loadAi();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, bundle]);

  const outdoor = bundle ? outdoorScore(bundle) : null;
  const clothing = bundle ? generateClothingAdvice(bundle) : '';
  const bgClass = bundle ? bgPreset(bundle.current.icon) : 'wx-bg-cloudy';

  const tabs: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'hourly', label: 'Hourly' },
    { id: 'daily', label: '7-Day' },
    { id: 'aqi', label: 'Air Quality' },
    { id: 'astro', label: 'Astronomy' },
    { id: 'ai', label: 'AI Insights' },
  ];

  return (
    <div className={`weather-tool ${bgClass}`}>
      <div className="weather-inner">
        {/* Search */}
        <div className="weather-search-wrap" ref={searchRef}>
          <div className="weather-search-bar">
            <Icon name="search" size={18} />
            <input
              type="search"
              role="combobox"
              aria-expanded={searchOpen && suggestions.length > 0}
              aria-controls="weather-suggestions-list"
              aria-autocomplete="list"
              aria-label="Search city or location"
              placeholder="Search any city… (London, Dhaka, Tokyo)"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onFocus={() => suggestions.length > 0 && setSearchOpen(true)}
            />
            <button
              type="button"
              className="weather-gps-btn"
              aria-label="Use my location"
              onClick={() => void detectGpsLocation().then(loadLocation).catch(() => setError('Could not detect location'))}
            >
              <Icon name="globe" size={16} />
            </button>
          </div>
          {searchOpen && suggestions.length > 0 && (
            <ul className="weather-suggestions" role="listbox" id="weather-suggestions-list">
              {suggestions.map((s) => (
                <li key={s.slug}>
                  <button type="button" role="option" aria-selected={false} onClick={() => void loadLocation(s)}>
                    <span className="weather-sug-name">{s.name}</span>
                    <span className="weather-sug-meta">{[s.region, s.country].filter(Boolean).join(', ')}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Quick chips */}
        {!bundle && !loading && (
          <div className="weather-chips">
            <span className="weather-chips-label">Popular:</span>
            {QUICK_CITIES.map((c) => (
              <button
                key={c}
                type="button"
                className="weather-chip"
                onClick={async () => {
                  const r = await searchLocations(c);
                  if (r[0]) void loadLocation(r[0]);
                }}
              >
                {c}
              </button>
            ))}
          </div>
        )}

        {/* Favorites & recents */}
        {(favorites.length > 0 || recents.length > 0) && !bundle && (
          <div className="weather-saved">
            {favorites.length > 0 && (
              <div>
                <p className="weather-saved-label">★ Favorites</p>
                <div className="weather-chips">
                  {favorites.map((f) => (
                    <button key={f.slug} type="button" className="weather-chip" onClick={() => void loadLocation(f)}>
                      {f.name}
                    </button>
                  ))}
                </div>
              </div>
            )}
            {recents.length > 0 && (
              <div>
                <p className="weather-saved-label">Recent</p>
                <div className="weather-chips">
                  {recents.slice(0, 5).map((r) => (
                    <button key={r.slug} type="button" className="weather-chip" onClick={() => void loadLocation(r)}>
                      {r.name}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {error && <div className="error-box">{error}</div>}
        {loading && <div className="weather-loading">Loading weather data…</div>}

        {bundle && !loading && (
          <>
            {/* Hero */}
            <div className="weather-hero">
              <div className="weather-hero-top">
                <div>
                  <h2 className="weather-city">{bundle.location.name}</h2>
                  <p className="weather-region">
                    {[bundle.location.region, bundle.location.country].filter(Boolean).join(', ')}
                  </p>
                  {localTime && <p className="weather-clock">{localTime} local</p>}
                </div>
                <button
                  type="button"
                  className={`weather-fav-btn${fav ? ' active' : ''}`}
                  aria-label={fav ? 'Remove from favorites' : 'Add to favorites'}
                  onClick={handleFavorite}
                >
                  {fav ? '★' : '☆'}
                </button>
              </div>
              <div className="weather-hero-main">
                <span className="weather-emoji" aria-hidden>{WEATHER_EMOJI[bundle.current.icon]}</span>
                <div>
                  <span className="weather-temp">{Math.round(bundle.current.tempC)}°</span>
                  <p className="weather-condition">{bundle.current.condition}</p>
                  <p className="weather-feels">Feels like {Math.round(bundle.current.feelsLikeC)}°C</p>
                </div>
              </div>
            </div>

            {/* Tabs */}
            <div className="weather-tabs" role="tablist">
              {tabs.map((t) => (
                <button
                  key={t.id}
                  type="button"
                  role="tab"
                  aria-selected={tab === t.id}
                  className={tab === t.id ? 'active' : ''}
                  onClick={() => setTab(t.id)}
                >
                  {t.label}
                </button>
              ))}
            </div>

            {/* Tab panels */}
            <div className="weather-panel">
              {tab === 'overview' && (
                <div className="weather-stats">
                  {[
                    { label: 'Humidity', value: `${bundle.current.humidity}%`, icon: 'cloud' },
                    { label: 'Wind', value: `${Math.round(bundle.current.windKph)} km/h ${windDirLabel(bundle.current.windDir)}`, icon: 'zap' },
                    { label: 'Pressure', value: `${Math.round(bundle.current.pressureMb)} hPa`, icon: 'settings' },
                    { label: 'Clouds', value: `${bundle.current.cloudPct}%`, icon: 'cloud' },
                    { label: 'UV Index', value: String(bundle.current.uv ?? bundle.daily[0]?.uvMax ?? '—'), icon: 'sun' },
                    { label: 'Precip', value: `${bundle.current.precipMm} mm`, icon: 'cloud' },
                  ].map((s) => (
                    <div key={s.label} className="weather-stat">
                      <Icon name={s.icon} size={18} />
                      <span className="weather-stat-label">{s.label}</span>
                      <span className="weather-stat-value">{s.value}</span>
                    </div>
                  ))}
                </div>
              )}

              {tab === 'hourly' && (
                <div className="weather-hourly-scroll">
                  {bundle.hourly.map((h) => (
                    <div key={h.time} className="weather-hour-card">
                      <span>{formatHour(h.time)}</span>
                      <span className="weather-hour-emoji">{WEATHER_EMOJI[h.icon]}</span>
                      <strong>{Math.round(h.tempC)}°</strong>
                      <span className="weather-hour-rain">{h.precipProb}%</span>
                    </div>
                  ))}
                </div>
              )}

              {tab === 'daily' && (
                <div className="weather-daily-list">
                  {bundle.daily.map((d) => (
                    <div key={d.date} className="weather-day-row">
                      <span className="weather-day-name">{formatDay(d.date)}</span>
                      <span>{WEATHER_EMOJI[d.icon]}</span>
                      <span className="weather-day-rain">💧 {d.precipProbMax}%</span>
                      <span className="weather-day-temps">
                        <span className="weather-tmax">{Math.round(d.tempMaxC)}°</span>
                        <span className="weather-tmin">{Math.round(d.tempMinC)}°</span>
                      </span>
                    </div>
                  ))}
                </div>
              )}

              {tab === 'aqi' && (
                bundle.airQuality ? (
                  <div className="weather-aqi">
                    <div className="weather-aqi-gauge" style={{ '--aqi-color': aqiColor(bundle.airQuality.aqi) } as React.CSSProperties}>
                      <span className="weather-aqi-num">{bundle.airQuality.aqi}</span>
                      <span className="weather-aqi-status">{bundle.airQuality.status}</span>
                    </div>
                    <p className="weather-aqi-rec">{bundle.airQuality.recommendation}</p>
                    <div className="weather-pollutants">
                      {[
                        { label: 'PM2.5', value: bundle.airQuality.pm25, unit: 'µg/m³' },
                        { label: 'PM10', value: bundle.airQuality.pm10, unit: 'µg/m³' },
                        { label: 'O₃', value: bundle.airQuality.ozone, unit: 'µg/m³' },
                        { label: 'NO₂', value: bundle.airQuality.no2, unit: 'µg/m³' },
                      ].map((p) => (
                        <div key={p.label} className="weather-pollutant">
                          <span>{p.label}</span>
                          <strong>{p.value.toFixed(1)} {p.unit}</strong>
                        </div>
                      ))}
                    </div>
                  </div>
                ) : (
                  <p className="weather-muted">Air quality data unavailable for this location.</p>
                )
              )}

              {tab === 'astro' && (
                <div className="weather-astro">
                  <div className="weather-astro-row">
                    <span>🌅 Sunrise</span>
                    <strong>{bundle.astronomy.sunrise}</strong>
                  </div>
                  <div className="weather-astro-row">
                    <span>🌇 Sunset</span>
                    <strong>{bundle.astronomy.sunset}</strong>
                  </div>
                  <div className="weather-astro-row">
                    <span>☀️ Solar noon</span>
                    <strong>{bundle.astronomy.solarNoon}</strong>
                  </div>
                  <div className="weather-astro-row">
                    <span>Day length</span>
                    <strong>{bundle.astronomy.dayLength}</strong>
                  </div>
                  <div className="weather-astro-row">
                    <span>🌙 Moon phase</span>
                    <strong>{bundle.astronomy.moonPhase}</strong>
                  </div>
                  <div className="weather-astro-section">
                    <p className="weather-astro-title">Golden hour</p>
                    <p>Morning: {bundle.astronomy.goldenMorning}</p>
                    <p>Evening: {bundle.astronomy.goldenEvening}</p>
                  </div>
                  <div className="weather-astro-section">
                    <p className="weather-astro-title">Blue hour</p>
                    <p>Morning: {bundle.astronomy.blueMorning}</p>
                    <p>Evening: {bundle.astronomy.blueEvening}</p>
                  </div>
                </div>
              )}

              {tab === 'ai' && (
                <div className="weather-ai">
                  {aiLoading && <p className="weather-loading">Generating AI insights…</p>}
                  {aiSummary && (
                    <div className="weather-ai-card">
                      <p className="weather-ai-label">✨ AI Summary</p>
                      <p>{aiSummary}</p>
                    </div>
                  )}
                  {outdoor && (
                    <div className="weather-ai-card">
                      <p className="weather-ai-label">Outdoor score</p>
                      <div className="weather-outdoor">
                        <span className="weather-outdoor-score" style={{ color: outdoor.score >= 60 ? 'var(--success-green)' : '#f97316' }}>
                          {outdoor.score}/100
                        </span>
                        <span>{outdoor.reason}</span>
                      </div>
                    </div>
                  )}
                  <div className="weather-ai-card">
                    <p className="weather-ai-label">👕 Clothing</p>
                    <p>{clothing}</p>
                  </div>
                  <button type="button" className="btn btn-ghost btn-sm" onClick={() => { setAiSummary(''); void loadAi(); }}>
                    Regenerate AI summary
                  </button>
                </div>
              )}
            </div>

            <p className="weather-credit">
              Powered by <a href="https://open-meteo.com" target="_blank" rel="noopener noreferrer">Open-Meteo</a> · No API key required
            </p>
          </>
        )}
      </div>
    </div>
  );
}
