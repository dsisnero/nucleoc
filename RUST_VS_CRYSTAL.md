# Nucleo Rust vs Crystal Implementation Comparison

## Core Components

### Rust nucleo-matcher crate (low-level):
- `chars` module - character utilities
- `Config` - matching configuration
- `Matcher` - core fuzzy matching algorithm
- `Utf32Str` - immutable UTF-32 string view
- `Utf32String` - owned UTF-32 string

### Crystal nucleoc (low-level):
- `Chars` module - character utilities ✓
- `Config` - matching configuration ✓
- `Matcher` - core fuzzy matching algorithm ✓
- `Utf32Str` - immutable UTF-32 string view ✓
- `Utf32String` - owned UTF-32 string ✓

### Rust nucleo crate (high-level):
- `Nucleo<T>` - main worker struct
- `Injector<T>` - for adding items
- `Snapshot<T>` - read-only match results
- `Item<T>` - matched item with columns
- `Match` - match metadata (score, index)
- `boxcar::Vec<T>` - concurrent append-only vector
- `MultiPattern` - multi-column pattern matching
- `par_sort` - parallel sorting
- `Worker` - background worker thread

### Crystal nucleoc (high-level):
- `Nucleo<T>` - exists but uses CML ❌
- `Injector<T>` - exists but uses CML ❌
- `Snapshot` - exists ✓
- `MatchResult` - similar to `Match` ✓
- `Boxcar` - concurrent vector ✓ (native version)
- `MultiPattern` - exists ✓ (native version)
- `ParSort` - parallel sorting ✓ (native version)
- `WorkerPool` - worker pool ✓ (native version)

## Missing in Crystal:
1. Proper `Nucleo<T>` implementation without CML
2. Proper `Injector<T>` without CML
3. `Item<T>` with column data support
4. Background worker thread with tick/timeout
5. Thread-safe snapshot updates
6. Proper multi-column item support

## Rust Nucleo API:
```rust
impl<T: Sync + Send + 'static> Nucleo<T> {
    pub fn new(config: Config, notify: impl Fn() + Sync + Send + 'static, num_threads: Option<usize>, columns: usize) -> Self
    pub fn active_injectors(&self) -> usize
    pub fn snapshot(&self) -> &Snapshot<T>
    pub fn injector(&self) -> Injector<T>
    pub fn restart(&mut self, clear_snapshot: bool)
    pub fn update_config(&mut self, config: Config)
    pub fn sort_results(&mut self, sort_results: bool)
    pub fn reverse_items(&mut self, reverse_items: bool)
    pub fn tick(&mut self, timeout: u64) -> Status
}
```

## Rust Injector API:
```rust
impl<T> Injector<T> {
    pub fn push(&self, value: T, fill_columns: impl FnOnce(&T, &mut [Utf32String])) -> u32
    pub fn extend<I>(&self, values: I, fill_columns: impl Fn(&T, &mut [Utf32String]))
    pub fn injected_items(&self) -> u32
    pub fn get(&self, index: u32) -> Option<Item<'_, T>>
}
```

## Rust Snapshot API:
```rust
impl<T> Snapshot<T> {
    pub fn item_count(&self) -> u32
    pub fn pattern(&self) -> &MultiPattern
    pub fn matched_item_count(&self) -> u32
    pub fn matched_items(&self, range: impl RangeBounds<u32>) -> impl Iterator<Item = Item<'_, T>>
    pub fn get_item(&self, index: u32) -> Option<Item<'_, T>>
    pub fn matches(&self) -> &[Match]
    pub fn get_matched_item(&self, n: u32) -> Option<Item<'_, T>>
}
```

## Implementation Plan for Crystal:

1. Create native `Nucleo(T)` class using `Channel` and `spawn`
2. Create native `Injector(T)` using `Boxcar` for concurrent appends
3. Update `Snapshot` to support generic type `T`
4. Add `Item(T)` struct with column data
5. Implement background worker fiber with `tick` method
6. Add multi-column support with `fill_columns` callback
7. Implement proper timeout handling
8. Add thread-safe snapshot updates