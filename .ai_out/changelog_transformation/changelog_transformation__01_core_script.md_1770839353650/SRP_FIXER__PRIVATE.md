# SRP_FIXER__PRIVATE: Phase 01 -- Core Script

## Decision Log

### Primary Assessment
The script at 548 lines is well-structured. Every function has a clear single purpose. The DRY fixer already improved the code by extracting `_sorted_entries()` and removing dead code. No further structural changes are warranted.

### `cmd_create()` Deep Dive
This was the only candidate for SRP extraction. At 116 lines it contains:
- Arg parsing (25 lines)
- Validation (20 lines)
- File writing (54 lines)
- Output (1 line)

I considered extracting validation into `_validate_create_args "$impact" "$entry_type"`. The function would be ~20 lines and take 2 string arguments. It would return 1 on failure with error messages to stderr.

**Why I rejected this:**
1. The overhead of a separate function in bash (function definition, argument passing, calling convention) is disproportionate to 20 lines of straightforward validation
2. The current code reads perfectly fine top-to-bottom with comments marking each section
3. Adding the function would increase total line count by ~4 lines (function header, closing brace, blank lines) while removing 0 lines from `cmd_create()` -- it would just add indirection
4. The Pareto test: Would this extraction deliver 80% of the value of a full refactor? No. The value is near-zero because the existing code is already clear.

### `_file_to_jsonl()` Complexity Assessment
This is 114 lines of awk doing:
- Frontmatter boundary detection (state machine)
- Map field parsing (nested YAML)
- Array field parsing
- Type-aware JSON emission (strings, numbers, arrays, objects)
- JSON escaping

All sub-concerns are deeply intertwined in the awk state machine. The emit() function references all accumulated state. Splitting would mean either:
- Multiple awk passes (performance penalty, complexity increase)
- Piping between awk processes (fragile, complex)
- Awk library files (non-standard, portability concern)

None of these are improvements. The awk is complex but cohesive.

### Scattered Responsibility Audit
I specifically checked for the more harmful form of SRP violation -- logic that belongs together but is spread across files/functions. Found none:
- Each YAML operation (read field, write frontmatter, full parse) is different enough to warrant separate functions
- ID generation, resolution, and extraction are all distinct operations correctly housed in separate functions
- The command dispatch at the bottom of the file is the standard bash pattern and correctly separated from command implementations
