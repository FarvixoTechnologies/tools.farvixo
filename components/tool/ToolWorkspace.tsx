'use client';

import dynamic from 'next/dynamic';
import type { ShareFile } from './ShareModal';

const FabRail = dynamic(() => import('./FabRail'), { ssr: false });

export interface ToolWorkspaceProps {
  children: React.ReactNode;
  file?: ShareFile | null;
  toolSlug?: string;
  onFilesPasted?: (files: File[]) => void;
}

/** Wraps tool UI with universal FAB rail (upload + result phases). */
export default function ToolWorkspace({ children, file, toolSlug, onFilesPasted }: ToolWorkspaceProps) {
  return (
    <div className="tool-workspace">
      {children}
      <FabRail file={file ?? null} toolSlug={toolSlug} onFilesPasted={onFilesPasted} />
    </div>
  );
}
