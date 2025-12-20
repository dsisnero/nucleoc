# Nucleoc - Fuzzy Matcher for Crystal

[![CI](https://github.com/dsisnero/nucleoc/actions/workflows/ci.yml/badge.svg)](https://github.com/dsisnero/nucleoc/actions/workflows/ci.yml)
[![GitHub license](https://img.shields.io/github/license/dsisnero/nucleoc)](https://github.com/dsisnero/nucleoc/blob/main/LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/dsisnero/nucleoc)](https://github.com/dsisnero/nucleoc/releases)
[![Crystal Shards](https://img.shields.io/badge/crystal-shards-blue)](https://crystal-lang.org)

Nucleoc is a Crystal port of the [nucleo](https://github.com/helix-editor/nucleo) fuzzy matcher from Rust.
It provides high-performance fuzzy matching algorithms for text search and filtering.

## Status

✅ **Production Ready** - This is a complete port of the Rust nucleo library with full fuzzy matching functionality implemented and tested.

## Features

- [x] Exact string matching
- [x] Case-sensitive and case-insensitive matching
- [x] Configurable scoring parameters
- [x] Fuzzy matching (greedy and optimal algorithms)
- [x] Substring matching
- [x] Prefix/Postfix matching
- [x] Pattern parsing
- [x] Unicode normalization
- [x] High-performance optimizations

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     nucleoc:
       github: dsisnero/nucleoc
   ```

2. Run `shards install`

## Tutorial: Complete Guide to Using Nucleoc

### 1. Basic Usage

#### Simple Fuzzy Matching

```crystal
require "nucleoc"

# Create a matcher with default configuration
matcher = Nucleoc::Matcher.new

# Fuzzy match with score
if score = matcher.fuzzy_match("hello world", "hlo")
  puts "Match found! Score: #{score}"
end

# Fuzzy match with indices (character positions)
indices = [] of UInt32
if score = matcher.fuzzy_indices("hello world", "hlo", indices)
  puts "Score: #{score}, Indices: #{indices}"  # => [0, 2, 3]
end
```

### 2. Matching Algorithms

#### Exact Matching
```crystal
matcher = Nucleoc::Matcher.new

# Returns score if strings match exactly
score = matcher.exact_match("hello", "hello")  # => 140
score = matcher.exact_match("Hello", "hello")  # => 140 (case-insensitive by default)

# With indices
indices = [] of UInt32
score = matcher.exact_indices("crystal", "crystal", indices)
# score = 140, indices = [0, 1, 2, 3, 4, 5, 6]
```

#### Substring Matching
```crystal
matcher = Nucleoc::Matcher.new

# Find needle as contiguous substring
score = matcher.substring_match("hello world", "world")  # => 96
score = matcher.substring_match("hello world", "lo wo")   # => 96

# With indices
indices = [] of UInt32
score = matcher.substring_indices("hello world", "world", indices)
# score = 96, indices = [6, 7, 8, 9, 10]
```

#### Prefix/Postfix Matching
```crystal
matcher = Nucleoc::Matcher.new

# Prefix: needle must match start of haystack
score = matcher.prefix_match("hello world", "hello")  # => 140
score = matcher.prefix_match("  hello world", "hello") # => 140 (ignores leading whitespace)

# Postfix: needle must match end of haystack
score = matcher.postfix_match("hello world", "world")  # => 96
score = matcher.postfix_match("hello world  ", "world") # => 96 (ignores trailing whitespace)
```

#### Greedy Fuzzy Matching
```crystal
matcher = Nucleoc::Matcher.new

# Greedy algorithm (faster but may not find optimal score)
score = matcher.fuzzy_match_greedy("hello world", "hlo")  # => 140
```

### 3. Configuration

#### Custom Configuration
```crystal
# Default configuration (case-insensitive, normalized)
config = Nucleoc::Config::DEFAULT

# Custom configuration
config = Nucleoc::Config.new(
  ignore_case: false,      # Case-sensitive matching
  normalize: true,         # Unicode normalization
  prefer_prefix: false,    # Don't give bonus to matches near start
  delimiter_chars: "/,:;|", # Characters that act as word boundaries
  bonus_boundary_white: Nucleoc::BONUS_BOUNDARY + 2_u16,
  bonus_boundary_delimiter: Nucleoc::BONUS_BOUNDARY + 1_u16,
  initial_char_class: Nucleoc::CharClass::Whitespace
)

matcher = Nucleoc::Matcher.new(config)
```

#### File Path Configuration
```crystal
# Optimized for matching file paths
config = Nucleoc::Config::DEFAULT.match_paths
matcher = Nucleoc::Matcher.new(config)

# On Unix: delimiter_chars = "/"
# On Windows: delimiter_chars = "/\\"
```

### 4. Pattern Parsing

#### Basic Patterns
```crystal
# Parse a pattern with multiple atoms (space-separated)
pattern = Nucleoc::Pattern.parse("hello world")
# Matches "hello" AND "world" (both must match)

# Parse with specific case handling
pattern = Nucleoc::Pattern.parse("Hello World",
  case_matching: Nucleoc::CaseMatching::Smart,
  normalization: Nucleoc::Normalization::Smart
)
```

#### Pattern Syntax
```crystal
# ^ = prefix match
pattern = Nucleoc::Pattern.parse("^hello")  # Must start with "hello"

# ' = substring match
pattern = Nucleoc::Pattern.parse("'world")  # Must contain "world" as substring

# $ = postfix match (or exact if combined with ^)
pattern = Nucleoc::Pattern.parse("world$")  # Must end with "world"
pattern = Nucleoc::Pattern.parse("^hello$") # Must be exactly "hello"

# ! = negative match
pattern = Nucleoc::Pattern.parse("!error")  # Must NOT contain "error"

# Escaping special characters
pattern = Nucleoc::Pattern.parse("\\!hello")  # Literal "!hello"
pattern = Nucleoc::Pattern.parse("\\^start")  # Literal "^start"
pattern = Nucleoc::Pattern.parse("\\'quote")  # Literal "'quote"
```

#### Using Patterns with Matcher
```crystal
matcher = Nucleoc::Matcher.new
pattern = Nucleoc::Pattern.parse("hello world")

# Match pattern against haystack
score = pattern.match(matcher, "hello beautiful world")
# score = combined score of "hello" and "world" matches

# With indices
indices = [] of Array(UInt32)
score = pattern.match(matcher, "hello beautiful world", indices)
# indices = [[0, 1, 2, 3, 4], [16, 17, 18, 19, 20]]
```

### 5. Advanced Features

#### Parallel Matching
```crystal
# Match multiple haystacks against single needle in parallel
haystacks = ["hello", "world", "foo", "bar"]
needle = "lo"

# Returns array of scores in same order as input
scores = Nucleoc.parallel_fuzzy_match(haystacks, needle)
# scores = [score_for_hello, score_for_world, nil, nil]

# With indices
results = Nucleoc.parallel_fuzzy_indices(haystacks, needle)
# results = [{score, indices}, {score, indices}, nil, nil]
```

#### Custom Worker Pool
```crystal
# Create worker pool with custom size
pool = Nucleoc::WorkerPool.new(workers: 4)

# Batch matching
scores, indices = pool.match_many(haystacks, needle, compute_indices: true)
```

#### Direct API Functions
```crystal
# Static convenience methods
score = Nucleoc.fuzzy_match("hello world", "hlo")
score = Nucleoc.substring_match("hello world", "world")
score = Nucleoc.prefix_match("hello world", "hello")
score = Nucleoc.postfix_match("hello world", "world")

# With indices
result = Nucleoc.fuzzy_match_indices("hello world", "hlo")
# result = {score, indices}
```

### 6. Nucleo API (Advanced)

#### Managing Collections
```crystal
# Create a Nucleo instance for managing collections
nucleo = Nucleoc.new_matcher

# Add items
nucleo.add("hello")
nucleo.add_all(["world", "foo", "bar"])

# Update pattern
nucleo.pattern = "lo"  # Sets pattern to "lo"

# Get matches
snapshot = nucleo.match
snapshot.items.each do |result|
  puts "#{result.item}: #{result.score}"
end

# Clear items
nucleo.clear
```

#### Incremental Updates with Injector
```crystal
nucleo = Nucleoc.new_matcher

# Get injector for batch operations
injector = nucleo.injector

# Add items through injector
injector.inject(0, "hello")
injector.extend(["world", "foo", "bar"])

# Injector automatically unregisters when done
```

### 7. Debugging and Logging

```crystal
# Enable debug logging
Log.setup(:debug)

matcher = Nucleoc::Matcher.new
score = matcher.fuzzy_match("hello world", "hlo")
# Logs include matrix layout, scoring steps, and reconstruction

# Or set environment variable
# LOG_LEVEL=DEBUG crystal run your_script.cr
```

### 8. Performance Tips

1. **Reuse Matchers**: Create matcher once and reuse for multiple matches
2. **Use Appropriate Algorithm**: Choose exact/substring when possible instead of fuzzy
3. **Batch Operations**: Use `parallel_fuzzy_match` for multiple haystacks
4. **Pre-compile Patterns**: Parse patterns once and reuse
5. **Configure Delimiters**: Set appropriate `delimiter_chars` for your use case

### 9. Common Use Cases

#### File Search
```crystal
config = Nucleoc::Config::DEFAULT.match_paths
matcher = Nucleoc::Matcher.new(config)

# Match file paths
files = ["src/nucleoc/api.cr", "spec/nucleoc_spec.cr", "README.md"]
pattern = Nucleoc::Pattern.parse("nucleoc cr")

files.each do |file|
  if score = pattern.match(matcher, file)
    puts "#{file}: #{score}"
  end
end
```

#### Autocomplete
```crystal
config = Nucleoc::Config.new(prefer_prefix: true)
matcher = Nucleoc::Matcher.new(config)

options = ["create", "read", "update", "delete", "config"]
query = "cr"

options.each do |option|
  if score = matcher.fuzzy_match(option, query)
    puts "#{option}: #{score}"
  end
end
# "create" gets bonus for starting with "cr"
```

#### Filtering Lists
```crystal
matcher = Nucleoc::Matcher.new
items = ["apple", "banana", "cherry", "date", "elderberry"]
pattern = Nucleoc::Pattern.parse("!e a")  # No 'e', contains 'a'

filtered = items.select do |item|
  pattern.match(matcher, item)
end
# filtered = ["banana", "date"]
```

## Configuration Reference

### Config Struct Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `delimiter_chars` | `String` | `"/,:;|"` | Characters that act as word delimiters |
| `bonus_boundary_white` | `UInt16` | `BONUS_BOUNDARY + 2` | Bonus for boundary after whitespace |
| `bonus_boundary_delimiter` | `UInt16` | `BONUS_BOUNDARY + 1` | Bonus for boundary after delimiter |
| `initial_char_class` | `CharClass` | `CharClass::Whitespace` | Class for start of string |
| `normalize?` | `Bool` | `true` | Enable Unicode normalization |
| `ignore_case?` | `Bool` | `true` | Case-insensitive matching |
| `prefer_prefix?` | `Bool` | `false` | Give bonus to matches near start |

### Character Classes

Nucleoc uses character classification for scoring bonuses:

```crystal
enum CharClass
  Whitespace  # Space, tab, newline
  Delimiter   # Characters in delimiter_chars
  NonWord     # Symbols like @, #, $
  Number      # 0-9
  Lower       # a-z
  Upper       # A-Z
end
```

### Scoring Constants

```crystal
SCORE_MATCH = 16                 # Base score for each match
PENALTY_GAP_START = 3           # Penalty for starting a gap
PENALTY_GAP_EXTENSION = 1       # Penalty for extending a gap
BONUS_BOUNDARY = 8              # Bonus for word boundary
BONUS_CONSECUTIVE = 4           # Bonus for consecutive matches
BONUS_FIRST_CHAR_MULTIPLIER = 2 # Multiplier for first character bonus
```

### Bonus Calculation

Bonuses are awarded for:
- Word boundaries (after whitespace/delimiter)
- CamelCase transitions (`lower → upper`)
- Number boundaries (`non-number → number`)
- Consecutive matches

## Debugging

Nucleoc uses Crystal's `Log` system. Set `LOG_LEVEL=DEBUG` to see detailed matcher traces, including matrix layout, scoring, and reconstruction steps:

```bash
LOG_LEVEL=DEBUG crystal spec
```

## Development Status

This project is a complete port of the Rust nucleo library. The implementation includes:

1. **Complete matching algorithms** - Fuzzy (greedy and optimal), exact, substring, prefix/postfix
2. **Pattern parsing** - Full pattern syntax with operators and escaping
3. **Unicode support** - Full Unicode normalization and character classification
4. **Performance optimizations** - Compressed matrix representation, prefiltering, efficient scoring
5. **Configuration** - Flexible scoring parameters and matching options

### Feature Parity with Rust Nucleo

- ✅ **Core matching algorithms** - All algorithms from Rust implementation
- ✅ **Scoring system** - Exact scoring constants and bonus calculations
- ✅ **Unicode handling** - Full Unicode normalization and case folding
- ✅ **Pattern parsing** - Complete pattern syntax with operators
- ✅ **Core data structures** - BoxcarVector, worker pool, parallel sort
- ✅ **Test coverage** - 125/125 tests passing with exact behavior matching

### Feature Status

| Feature | Status | Notes |
|---------|--------|-------|
| **Core Matching Algorithms** | ✅ **Complete** | Fuzzy (greedy/optimal), exact, substring, prefix/postfix |
| **Pattern Parsing** | ✅ **Complete** | Full syntax with operators and escaping |
| **Unicode Support** | ✅ **Complete** | Normalization and case folding |
| **Configuration System** | ✅ **Complete** | Custom scoring, delimiters, case handling |
| **Boxcar Data Structure** | ✅ **Complete** | Lock-free vector with snapshots (`src/nucleoc/boxcar.cr`) |
| **Worker Pool** | ✅ **Complete** | Thread pool for concurrent matching (`src/nucleoc/worker_pool.cr`) |
| **CML Worker Pool** | ✅ **Complete** | Concurrent ML-based agent system (`src/nucleoc/worker_pool_cml.cr`) |
| **Parallel Sorting** | 🔄 **In Progress** | Parallel quicksort with cancellation (`src/nucleoc/par_sort.cr`) - bug fixes needed (issue nucleoc-8f6) |
| **MultiPattern** | 🔄 **Planned** | Incremental pattern updates (issue nucleoc-efu) |
| **Advanced CML Patterns** | 🔄 **Planned** | choose, wrap, with_nack, guard (issue nucleoc-fep) |
| **Parallel Matcher** | 🔄 **Planned** | Intra-task parallelism like Rayon's par_iter (issue nucleoc-aa2) |
| **Concurrency Tests** | 🔄 **Planned** | Comprehensive race condition testing (issue nucleoc-2gq) |
| **Error Handling & Recovery** | 🔄 **Planned** | Supervisor patterns, circuit breaker (issue nucleoc-bsy) |

**Legend:** ✅ = Implemented, 🔄 = In Progress/Planned, ❌ = Not Started

## Development

### Prerequisites
- Crystal 1.18.2 or later
- Git

### Setup
```bash
git clone https://github.com/dsisnero/nucleoc.git
cd nucleoc
shards install
```

### Running Tests
```bash
crystal spec
```

### Code Quality
```bash
# Format code
crystal tool format src/ spec/

# Run linter
ameba
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer

See the full list of [contributors](https://github.com/dsisnero/nucleoc/contributors) who participated in this project.

## Acknowledgments

- Based on the [nucleo](https://github.com/helix-editor/nucleo) Rust library by Pascal Kuthe and the Helix editor team
- Inspired by fzf and skim fuzzy matching algorithms
- Uses [CML](https://github.com/dsisnero/cml) for concurrent ML patterns

## API Quick Reference

### Core Classes

| Class | Purpose | Key Methods |
|-------|---------|-------------|
| `Matcher` | Main matching engine | `fuzzy_match`, `exact_match`, `substring_match`, `prefix_match`, `postfix_match` |
| `Pattern` | Parsed query pattern | `parse`, `match` |
| `Config` | Matching configuration | `new`, `match_paths`, `bonus_for` |
| `WorkerPool` | Parallel matching | `match_many` |
| `Nucleo` | Collection manager | `add`, `clear`, `match`, `injector` |

### Static Convenience Methods

```crystal
Nucleoc.fuzzy_match(haystack, needle) → UInt16?
Nucleoc.substring_match(haystack, needle) → UInt16?
Nucleoc.prefix_match(haystack, needle) → UInt16?
Nucleoc.postfix_match(haystack, needle) → UInt16?
Nucleoc.parallel_fuzzy_match(haystacks, needle) → Array(UInt16?)
Nucleoc.parallel_fuzzy_indices(haystacks, needle) → Array(Tuple(UInt16, Array(UInt32))?)
```

### Pattern Syntax Cheat Sheet

| Syntax | Meaning | Example |
|--------|---------|---------|
| `text` | Fuzzy match | `"hello"` matches `"hlo"` |
| `'text` | Substring match | `"'world"` matches `"hello world"` |
| `^text` | Prefix match | `"^hello"` matches `"hello world"` |
| `text$` | Postfix match | `"world$"` matches `"hello world"` |
| `^text$` | Exact match | `"^hello$"` matches only `"hello"` |
| `!text` | Negative match | `"!error"` excludes `"error.log"` |
| `a b` | AND (space) | `"hello world"` matches both |
| `\` | Escape | `"\!hello"` matches literal `"!hello"` |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
