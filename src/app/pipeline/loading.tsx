/** Route-level loading UI. Next.js shows this while the server component awaits its data. */
export default function PipelineLoading() {
  return (
    <div className="flex flex-col gap-4">
      <div className="ringly-shimmer h-6 w-32 rounded" />
      <div className="flex gap-3 overflow-x-hidden">
        {[0, 1, 2, 3].map((column) => (
          <div key={column} className="flex w-[260px] shrink-0 flex-col gap-2">
            <div className="ringly-shimmer h-4 w-20 rounded" />
            {[0, 1].map((card) => (
              <div key={card} className="ringly-shimmer h-28 rounded-(--radius-card)" />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
