import { describe, expect, it } from "vitest";
import { updateRangeSelection } from "@/lib/range-selection";

describe("updateRangeSelection", () => {
  const orderedIds = ["build-1", "build-2", "build-3", "build-4"];

  it("toggles a single target when range selection is not requested", () => {
    const result = updateRangeSelection({
      selectedIds: new Set(["build-1"]),
      orderedIds,
      targetId: "build-2",
      anchorId: "build-1",
      range: false,
    });

    expect([...result]).toEqual(["build-1", "build-2"]);
  });

  it("selects every row between the anchor and target on shift selection", () => {
    const result = updateRangeSelection({
      selectedIds: new Set(["build-1"]),
      orderedIds,
      targetId: "build-4",
      anchorId: "build-1",
      range: true,
    });

    expect([...result]).toEqual(["build-1", "build-2", "build-3", "build-4"]);
  });

  it("deselects every row in the range when the target is already selected", () => {
    const result = updateRangeSelection({
      selectedIds: new Set(["build-1", "build-2", "build-3", "build-4"]),
      orderedIds,
      targetId: "build-4",
      anchorId: "build-2",
      range: true,
    });

    expect([...result]).toEqual(["build-1"]);
  });

  it("falls back to a single toggle when the anchor is not on the current page", () => {
    const result = updateRangeSelection({
      selectedIds: new Set(["build-1"]),
      orderedIds,
      targetId: "build-3",
      anchorId: "other-build",
      range: true,
    });

    expect([...result]).toEqual(["build-1", "build-3"]);
  });
});
