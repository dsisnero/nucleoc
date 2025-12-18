# Nucleoc Agents System

Nucleoc is a Crystal port of the nucleo_rust fuzzy matching library, designed with a modern agent-based architecture for concurrent processing. This document describes the agent system and how to work with the codebase.

## Development Tools

### Code Formatting
```bash
# Format all Crystal files
crystal tool format

# Format specific files
crystal tool format src/**/*.cr spec/**/*.cr
```

### Static Analysis
```bash
# Run Ameba linter with auto-fix
ameba --fix

# Run Ameba linter without fixes
ameba

# Run Ameba on specific files
ameba src/**/*.cr
```

### Testing
```bash
# Run all specs
crystal spec

# Run specific spec file
crystal spec spec/nucleoc_spec.cr

# Run with verbose output
crystal spec --verbose
```

### Building
```bash
# Build the library
crystal build src/nucleoc.cr

# Build with release optimizations
crystal build --release src/nucleoc.cr
```
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**
```bash
bd ready --json
```

**Create new issues:**
```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
bd create "Subtask" --parent <epic-id> --json  # Hierarchical subtask (gets ID like epic-id.1)
```

**Claim and update:**
```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**
```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`
6. **Commit together**: Always commit the `.beads/issues.jsonl` file together with the code changes so issue state stays in sync with code state

### Writing Self-Contained Issues

Issues must be fully self-contained - readable without any external context (plans, chat history, etc.). A future session should understand the issue completely from its description alone.

**Required elements:**
- **Summary**: What and why in 1-2 sentences
- **Files to modify**: Exact paths (with line numbers if relevant)
- **Implementation steps**: Numbered, specific actions
- **Example**: Show before → after transformation when applicable

**Optional but helpful:**
- Edge cases or gotchas to watch for
- Test references (point to test files or test_data examples)
- Dependencies on other issues

**Bad example:**
```
Implement the refactoring from the plan
```

**Good example:**
```
Add timeout parameter to fetchUser() in src/api/users.ts

1. Add optional timeout param (default 5000ms)
2. Pass to underlying fetch() call
3. Update tests in src/api/users.test.ts

Example: fetchUser(id) → fetchUser(id, { timeout: 3000 })
Depends on: bd-abc123 (fetch wrapper refactor)
```

### Dependencies: Think "Needs", Not "Before"

`bd dep add X Y` = "X needs Y" = Y blocks X

**TRAP**: Temporal words ("Phase 1", "before", "first") invert your thinking!
```
WRONG: "Phase 1 before Phase 2" → bd dep add phase1 phase2
RIGHT: "Phase 2 needs Phase 1" → bd dep add phase2 phase1
```
**Verify**: `bd blocked` - tasks blocked by prerequisites, not dependents.

### Auto-Sync

bd automatically syncs with git:
- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### GitHub Copilot Integration

If using GitHub Copilot, also create `.github/copilot-instructions.md` for automatic instruction loading.
Run `bd onboard` to get the content, or see step 2 of the onboard instructions.

### MCP Server (Recommended)

If using Claude or MCP-compatible clients, install the beads MCP server:

```bash
pip install beads-mcp
```

Add to MCP config (e.g., `~/.config/claude/config.json`):
```json
{
  "beads": {
    "command": "beads-mcp",
    "args": []
  }
}
```

Then use `mcp__beads__*` functions instead of CLI commands.

### Managing AI-Generated Planning Documents

AI assistants often create planning and design documents during development:
- PLAN.md, IMPLEMENTATION.md, ARCHITECTURE.md
- DESIGN.md, CODEBASE_SUMMARY.md, INTEGRATION_PLAN.md
- TESTING_GUIDE.md, TECHNICAL_DESIGN.md, and similar files

**Best Practice: Use a dedicated directory for these ephemeral files**

**Recommended approach:**
- Create a `history/` directory in the project root
- Store ALL AI-generated planning/design docs in `history/`
- Keep the repository root clean and focused on permanent project files
- Only access `history/` when explicitly asked to review past planning

**Example .gitignore entry (optional):**
```
# AI planning documents (ephemeral)
history/
```

**Benefits:**
- ✅ Clean repository root
- ✅ Clear separation between ephemeral and permanent documentation
- ✅ Easy to exclude from version control if desired
- ✅ Preserves planning history for archeological research
- ✅ Reduces noise when browsing the project

### CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ✅ Store AI planning docs in `history/` directory
- ✅ Run `bd <cmd> --help` to discover available flags
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT clutter repo root with planning documents

For more details, see README.md and QUICKSTART.md.


## Concurrency with CML (Concurrent ML)

Nucleoc uses a port of Concurrent ML (CML) for its agent-based concurrency system. CML provides first-class synchronous operations and channels for building concurrent systems.

### Key CML Concepts

#### 1. **Channels**
```crystal
require "cml"

# Create a channel
channel = CML::Channel(String).new

# Spawn a fiber to send data
spawn do
  channel.send("Hello from fiber!")
end

# Receive data in main fiber
message = channel.receive
puts message  # => "Hello from fiber!"
```

#### 2. **Synchronous Operations**
```crystal
# Create a synchronous event
event = CML::Event(String).new("data")

# Wait for the event
result = event.sync
```

#### 3. **Choice Operations**
```crystal
# Create multiple channels
ch1 = CML::Channel(Int32).new
ch2 = CML::Channel(Int32).new

# Spawn senders
spawn { ch1.send(1) }
spawn { ch2.send(2) }

# Choose the first available message
choice = CML.choice(
  CML.receive(ch1) { |value| "From ch1: #{value}" },
  CML.receive(ch2) { |value| "From ch2: #{value}" }
)

result = choice.sync
puts result  # => "From ch1: 1" or "From ch2: 2"
```

### Agent Architecture

Nucleoc implements several agent types for fuzzy matching:

#### 1. **Matcher Agent**
- **Purpose**: Core fuzzy matching algorithm execution
- **Concurrency**: Uses CML channels for pattern input and result output
- **Lifecycle**: Long-running fiber that processes matching requests

```crystal
class MatcherAgent
  @input_channel : CML::Channel(Pattern)
  @output_channel : CML::Channel(MatchResult)

  def initialize
    @input_channel = CML::Channel(Pattern).new
    @output_channel = CML::Channel(MatchResult).new
    start
  end

  def start
    spawn do
      loop do
        pattern = @input_channel.receive
        result = match_pattern(pattern)
        @output_channel.send(result)
      end
    end
  end
end
```

#### 2. **Worker Pool Agent**
- **Purpose**: Manages a pool of matcher agents
- **Concurrency**: Distributes work using CML choice operations
- **Load Balancing**: Implements work-stealing algorithm

```crystal
class WorkerPool
  @workers : Array(MatcherAgent)
  @work_channel : CML::Channel(WorkItem)

  def initialize(pool_size : Int32)
    @workers = Array.new(pool_size) { MatcherAgent.new }
    @work_channel = CML::Channel(WorkItem).new
    start_dispatcher
  end

  def start_dispatcher
    spawn do
      loop do
        work = @work_channel.receive

        # Create choice between all workers
        choices = @workers.map do |worker|
          CML.send(worker.input_channel, work) { worker }
        end

        # Choose first available worker
        chosen_worker = CML.choice(*choices).sync
        # Work is automatically sent to the chosen worker
      end
    end
  end
end
```

#### 3. **Result Aggregator Agent**
- **Purpose**: Collects and sorts results from multiple workers
- **Concurrency**: Merges streams using CML merge operations
- **Sorting**: Implements parallel merge sort

```crystal
class ResultAggregator
  @result_channels : Array(CML::Channel(MatchResult))
  @sorted_output : CML::Channel(Array(MatchResult))

  def initialize(worker_count : Int32)
    @result_channels = Array.new(worker_count) { CML::Channel(MatchResult).new }
    @sorted_output = CML::Channel(Array(MatchResult)).new
    start_aggregator
  end

  def start_aggregator
    spawn do
      all_results = [] of MatchResult

      # Merge all result channels
      merge = CML.merge(*@result_channels)

      loop do
        choice = CML.choice(
          merge.receive { |result| all_results << result },
          CML.timeout(100.milliseconds) { :timeout }
        )

        case choice.sync
        when :timeout
          # Sort and output results
          sorted = parallel_sort(all_results)
          @sorted_output.send(sorted)
          all_results.clear
        end
      end
    end
  end
end

### Performance Patterns

#### 1. **Pipeline Pattern**
```crystal
# Create processing pipeline
input_ch = CML::Channel(String).new
process_ch = CML::Channel(Processed).new
output_ch = CML::Channel(Result).new

# Stage 1: Normalization
spawn do
  loop do
    text = input_ch.receive
    normalized = normalize(text)
    process_ch.send(normalized)
  end
end

# Stage 2: Matching
spawn do
  loop do
    processed = process_ch.receive
    result = match(processed)
    output_ch.send(result)
  end
end
```

#### 2. **Fan-out/Fan-in Pattern**
```crystal
def parallel_process(items : Array(Item), workers : Int32) : Array(Result)
  input_ch = CML::Channel(Item).new
  result_chs = Array.new(workers) { CML::Channel(Result).new }

  # Fan-out: Distribute items to workers
  spawn do
    items.each do |item|
      # Round-robin distribution
      worker_idx = rand(workers)
      result_chs[worker_idx].send(process_item(item))
    end
  end

  # Fan-in: Collect results
  results = [] of Result
  merge = CML.merge(*result_chs)

  items.size.times do
    results << merge.receive.sync
  end

  results
end
```

#### 3. **Supervisor Pattern**
```crystal
class Supervisor
  @agents : Array(CML::Channel(Signal))
  @health_check : CML::Channel(HealthStatus)

  def supervise(agent : -> Agent)
    control_ch = CML::Channel(Signal).new

    spawn do
      begin
        instance = agent.call
        control_ch.send(:started)

        loop do
          signal = control_ch.receive
          case signal
          when :restart
            # Handle restart logic
          when :stop
            break
          end
        end
      rescue ex
        control_ch.send(:crashed(ex))
        # Restart logic
      end
    end

    control_ch
  end
end
```

### Error Handling in Concurrent Systems

#### 1. **Timeout Patterns**
```crystal
def with_timeout(operation : -> T, timeout : Time::Span) : T?
  choice = CML.choice(
    CML.operation { operation.call },
    CML.timeout(timeout) { :timeout }
  )

  case choice.sync
  when :timeout
    nil
  else
    choice.sync
  end
end
```

#### 2. **Circuit Breaker Pattern**
```crystal
class CircuitBreaker
  @state = :closed
  @failure_count = 0
  @channel = CML::Channel(Operation).new

  def call(operation : -> T) : T?
    case @state
    when :open
      return nil  # Fast fail
    when :half_open
      # Try with caution
    when :closed
      # Normal operation
    end

    begin
      result = operation.call
      reset_failures
      result
    rescue ex
      record_failure
      raise ex
    end
  end
end
```

### Testing Concurrent Code

#### 1. **Deterministic Testing**
```crystal
describe "MatcherAgent" do
  it "processes patterns concurrently" do
    agent = MatcherAgent.new
    pattern = Pattern.new("test")

    # Send pattern
    agent.input_channel.send(pattern)

    # Receive result with timeout
    result = with_timeout(->{ agent.output_channel.receive }, 1.second)
    result.should_not be_nil
  end
end
```

#### 2. **Race Condition Testing**
```crystal
it "handles concurrent access correctly" do
  pool = WorkerPool.new(4)

  # Send multiple work items concurrently
  10.times do |i|
    spawn do
      pool.work_channel.send(WorkItem.new(i))
    end
  end

  # Verify all work was processed
  processed_count = 0
  10.times do
    # Each worker should output results
    # Implementation depends on your architecture
  end
end
```

## Development Workflow

1. **Write Code**: Implement agents using CML patterns
2. **Format**: `crystal tool format`
3. **Lint**: `ameba --fix`
4. **Test**: `crystal spec`
5. **Build**: `crystal build --release`

## Best Practices

1. **Use CML for all concurrency**: Avoid raw `spawn` and `Channel` when CML provides better abstractions
2. **Keep agents focused**: Each agent should have a single responsibility
3. **Use supervision trees**: For fault tolerance and lifecycle management
4. **Test concurrency explicitly**: Don't assume concurrent code works without testing
5. **Profile performance**: Use Crystal's built-in profiling tools to identify bottlenecks

## Resources

- [Crystal Language Official Documentation](https://crystal-lang.org/docs/)
- [CML Crystal Port Documentation](https://github.com/your-username/cml.cr)
- [Concurrent ML Papers](https://cml.cs.uchicago.edu/papers/cml.html)
- [Nucleo Rust Implementation](https://github.com/nucleo-org/nucleo)
```
Nucleoc uses a port of Concurrent ML (CML) for its agent-based concurrency system. CML provides first-class synchronous operations and channels for building concurrent systems.

### Key CML Concepts

#### 1. **Channels**
```crystal
require "cml"

# Create a channel
channel = CML::Channel(String).new

# Spawn a fiber to send data
spawn do
  channel.send("Hello from fiber!")
end

# Receive data in main fiber
message = channel.receive
puts message  # => "Hello from fiber!"
```

#### 2. **Synchronous Operations**
```crystal
# Create a synchronous event
event = CML::Event(String).new("data")

# Wait for the event
result = event.sync
```

#### 3. **Choice Operations**
```crystal
# Create multiple channels
ch1 = CML::Channel(Int32).new
ch2 = CML::Channel(Int32).new

# Spawn senders
spawn { ch1.send(1) }
spawn { ch2.send(2) }

# Choose the first available message
choice = CML.choice(
  CML.receive(ch1) { |value| "From ch1: #{value}" },
  CML.receive(ch2) { |value| "From ch2: #{value}" }
)

result = choice.sync
puts result  # => "From ch1: 1" or "From ch2: 2"
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
