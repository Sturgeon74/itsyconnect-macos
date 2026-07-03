export interface RangeSelectionInput {
  selectedIds: Set<string>;
  orderedIds: string[];
  targetId: string;
  anchorId: string | null;
  range: boolean;
}

export function updateRangeSelection({
  selectedIds,
  orderedIds,
  targetId,
  anchorId,
  range,
}: RangeSelectionInput): Set<string> {
  const next = new Set(selectedIds);
  const shouldSelect = !next.has(targetId);
  const targetIndex = orderedIds.indexOf(targetId);
  const anchorIndex = anchorId ? orderedIds.indexOf(anchorId) : -1;

  if (range && anchorIndex !== -1 && targetIndex !== -1) {
    const start = Math.min(anchorIndex, targetIndex);
    const end = Math.max(anchorIndex, targetIndex);
    const rangeIds = orderedIds.slice(start, end + 1);

    for (const id of rangeIds) {
      if (shouldSelect) {
        next.add(id);
      } else {
        next.delete(id);
      }
    }

    return next;
  }

  if (shouldSelect) {
    next.add(targetId);
  } else {
    next.delete(targetId);
  }

  return next;
}
