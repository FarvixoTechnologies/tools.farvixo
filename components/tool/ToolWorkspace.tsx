'use client';

import type { ShareFile } from './ShareModal';

export interface ToolWorkspaceProps {
  children: React.ReactNode;
  file?: ShareFile | null;
  toolSlug?: string;
  onFilesPasted?: (files: File[]) => void;
}

/** Simple wrapper around tool UI. */
export default function ToolWorkspace({ children }: ToolWorkspaceProps) {
  return <div className="tool-workspace">{children}</div>;
}
