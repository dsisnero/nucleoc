# Empty Pattern Fast Path Implementation Plan

## Problem
Currently, when matching with an empty pattern (needle = ""), Nucleo still scores every item, which is wasteful. Empty patterns should return the first N items instantly with score 0.

## Solution
Add fast path detection for empty patterns that returns immediately without scoring.

## Implementation Locations

### 1. `src/nucleoc/api.cr` - High-level API
- `parallel_fuzzy_match()` - Check if needle.empty? early
- `parallel_fuzzy_indices()` - Same check
- Return array of 0 scores for all items (or first max_results)

### 2. `src/nucleoc/matcher.cr` - Core matcher
- `fuzzy_match()` - Fast path for empty needle
- `fuzzy_indices()` - Fast path for empty needle
- `exact_match()`, `prefix_match()`, etc. - All should handle empty needle

### 3. `src/nucleoc/nucleo_native.cr` - Nucleo worker
- `Worker#process_items()` - Skip scoring if pattern is empty
- Return matches with score 0 for all items

## Code Changes

### API Level (`api.cr`)
```crystal
def self.parallel_fuzzy_match(
  haystacks : Array(String),
  needle : String,
  config : Config = Config.new,
  workers : Int32? = nil,
  strategy : Symbol = :auto,
  max_results : Int32? = nil
) : Array(UInt16?)
  # Fast path for empty needle
  if needle.empty?
    if max_results
      # Return 0 for first max_results items, nil for rest
      return Array.new(haystacks.size) { |i| i < max_results ? 0_u16 : nil }
    else
      # Return 0 for all items
      return Array.new(haystacks.size, 0_u16)
    end
  end

  # Existing logic...
end
```

### Matcher Level (`matcher.cr`)
```crystal
def fuzzy_match(haystack : String, needle : String) : UInt16?
  return 0_u16 if needle.empty?
  # Existing logic...
end

def fuzzy_indices(haystack : String, needle : String, indices : Array(UInt32)) : UInt16?
  if needle.empty?
    indices.clear
    return 0_u16
  end
  # Existing logic...
end
```

### Worker Level (`nucleo_native.cr`)
```crystal
private def process_items(start_idx : UInt32, end_idx : UInt32) : Nil
  return if start_idx >= end_idx

  matcher = @matchers.first
  pattern = @pattern.column_pattern(0)

  # Fast path for empty pattern
  if pattern.atoms.empty?
    (start_idx...end_idx).each do |idx|
      @matches << Match.new(0_u16, idx)
    end
    return
  end

  # Existing logic...
end
```

## Performance Impact

### Before
- Empty pattern: O(n) time, scores every item
- Memory: Allocates match structures for all items
- CPU: Full scoring algorithm runs

### After
- Empty pattern: O(1) time, immediate return
- Memory: Minimal allocations
- CPU: Simple array creation

## Testing

### Unit Tests
```crystal
describe "empty pattern fast path" do
  it "returns 0 scores for empty needle" do
    haystacks = ["hello", "world", "test"]
    results = Nucleoc.parallel_fuzzy_match(haystacks, "")
    results.should eq [0_u16, 0_u16, 0_u16]
  end

  it "respects max_results with empty needle" do
    haystacks = ["a", "b", "c", "d", "e"]
    results = Nucleoc.parallel_fuzzy_match(haystacks, "", max_results: 3)
    results.should eq [0_u16, 0_u16, 0_u16, nil, nil]
  end

  it "clears indices for empty needle" do
    matcher = Nucleoc::Matcher.new
    indices = [] of UInt32
    score = matcher.fuzzy_indices("hello", "", indices)
    score.should eq 0_u16
    indices.should be_empty
  end
end
```

### Benchmark Tests
```crystal
# Measure empty pattern performance
benchmark "empty pattern 10k items" do
  haystacks = generate_strings(10_000)
  Nucleoc.parallel_fuzzy_match(haystacks, "")
end

# Should be < 1ms even for 100k items
```

## Edge Cases

1. **Empty haystack array**: Should return empty array immediately
2. **max_results = 0**: Should return all nil
3. **max_results > array size**: Should return 0 for all items
4. **Concurrent access**: Thread-safe empty check
5. **Pattern with only whitespace**: Should it be considered empty? (Probably yes after normalization)

## Integration with Other Optimizations

This fast path works well with:
1. **Top-k selection**: When max_results is set, only return first N items
2. **Parallel chunking**: Empty pattern doesn't need parallel processing
3. **Memory reuse**: Can reuse existing result arrays

## Rollout Plan

1. Implement fast path in `api.cr` first (easiest, most impact)
2. Add to `matcher.cr` for consistency
3. Add to `nucleo_native.cr` for Nucleo API
4. Add comprehensive tests
5. Benchmark before/after
6. Document the behavior change