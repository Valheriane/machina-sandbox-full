export function makePageItems(total, current) {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);

  const items = [1];
  const left  = Math.max(2, current - 1);
  const right = Math.min(total - 1, current + 1);

  if (left > 2) items.push("…");
  for (let p = left; p <= right; p++) items.push(p);
  if (right < total - 1) items.push("…");

  items.push(total);
  return items;
}
