'use client';

export default function HistoryPage() {
  return (
    <div>
      <h1 className="dash-title">Job History</h1>
      <p className="muted mb-6">Your recent tool runs and downloads.</p>
      <div className="glass dash-empty">
        <p>No jobs yet. <a href="/tools">Use a tool</a> and your history will appear here.</p>
        <p className="muted mt-2">Browser-based tools process locally — history syncs when you sign in with cloud storage (Pro).</p>
      </div>
    </div>
  );
}
