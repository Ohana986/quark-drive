import type { ReactNode } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { Minus, Square, X } from "lucide-react";
import { toast } from "sonner";
import { isDesktop } from "../lib/backend";

const windowActions = [
  { label: "最小化", Icon: Minus, run: () => getCurrentWindow().minimize() },
  { label: "最大化或还原", Icon: Square, run: () => getCurrentWindow().toggleMaximize() },
  { label: "关闭窗口", Icon: X, run: () => getCurrentWindow().close() },
];

export default function WindowToolbar({
  title,
  status,
  children,
}: {
  title: string;
  status?: ReactNode;
  children?: ReactNode;
}) {
  const dragRegion = isDesktop ? true : undefined;

  return (
    <header
      data-tauri-drag-region={dragRegion}
      className="flex h-[58px] shrink-0 items-stretch gap-3 border-b border-[var(--line)] bg-[var(--panel)]/72 px-6 backdrop-blur-xl"
    >
      <div data-tauri-drag-region={dragRegion} className="flex min-w-0 flex-1 select-none items-center">
        {/* Tauri checks the exact event target; send hits on the label and its status to the drag region. */}
        <div className={isDesktop ? "pointer-events-none flex min-w-0 items-center gap-3" : "flex min-w-0 items-center gap-3"}>
          <h1 className="truncate text-[15px] font-semibold tracking-tight text-[var(--ink)]">
            {title}
          </h1>
          {status}
        </div>
      </div>
      {children ? <div className="flex shrink-0 items-center gap-2">{children}</div> : null}
      {isDesktop ? (
        <div role="group" aria-label="窗口控制" className="flex shrink-0 items-center gap-1.5">
          {windowActions.map(({ label, Icon, run }) => (
            <button
              key={label}
              type="button"
              aria-label={label}
              title={label}
              onClick={() => void run().catch(() => toast.error(`无法${label}`))}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-[var(--panel-2)] text-[var(--muted)] transition hover:bg-[var(--line)] hover:text-[var(--ink)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--accent)]"
            >
              <Icon aria-hidden="true" className="h-3.5 w-3.5" />
            </button>
          ))}
        </div>
      ) : null}
    </header>
  );
}
