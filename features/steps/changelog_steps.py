"""Step definitions for change_log CLI BDD tests."""

import json
import os
import re
import subprocess
from pathlib import Path

from behave import given, when, then
# anchor_points.step_matcher_choice
use_step_matcher = __import__('behave', fromlist=['use_step_matcher']).use_step_matcher

# Use regex matcher for more flexible step definitions
use_step_matcher("re")


# ============================================================================
# Helper Functions
# ============================================================================

def get_script(context):
    """Get the change_log script path, defaulting to ./change_log or using CHANGE_LOG_SCRIPT env var."""
    script = os.environ.get('CHANGE_LOG_SCRIPT')
    if script:
        return script
    return str(Path(context.project_dir) / 'change_log')


def create_entry(context, entry_id, title, impact=3, entry_type="default"):
    """Create a changelog entry fixture file in <test_dir>/change_log/.

    Uses deterministic timestamp filenames: 2024-01-01_00-00-{counter:02d}Z.md
    where counter is len(context.tickets) at call time.
    """
    changelog_dir = Path(context.test_dir) / 'change_log'
    changelog_dir.mkdir(parents=True, exist_ok=True)

    counter = len(context.tickets)
    filename = f'2024-01-01_00-00-{counter:02d}Z.md'
    entry_path = changelog_dir / filename

    escaped_title = title.replace('"', '\\"')
    content = f'''---
id: {entry_id}
title: "{escaped_title}"
created_iso: 2024-01-01T00:00:00Z
type: {entry_type}
impact: {impact}
---

'''
    entry_path.write_text(content)

    context.tickets[entry_id] = entry_path
    return entry_path


def find_entry_file(context, entry_id):
    """Find an entry file by searching frontmatter id: field.

    First checks context.tickets dict, then falls back to scanning files.
    """
    if hasattr(context, 'tickets') and entry_id in context.tickets:
        path = context.tickets[entry_id]
        if path.exists():
            return path

    # Fallback: scan change_log/ directory
    changelog_dir = Path(context.test_dir) / 'change_log'
    if not changelog_dir.exists():
        raise FileNotFoundError(f"Changelog directory not found at {changelog_dir}")

    for md_file in changelog_dir.glob('*.md'):
        content = md_file.read_text()
        if re.search(rf'^id:\s*{re.escape(entry_id)}\s*$', content, re.MULTILINE):
            return md_file

    raise FileNotFoundError(f"No entry file found with id: {entry_id}")


def extract_created_id(stdout):
    """Extract entry ID from create command output (JSON format)."""
    output = stdout.strip()
    if not output:
        return None
    try:
        data = json.loads(output)
        return data.get('id')
    except json.JSONDecodeError:
        return output


def _track_created_entry(context, command, result):
    """Track entry ID and path from create command JSON output."""
    if 'change_log create' not in command or result.returncode != 0:
        return
    created_id = extract_created_id(result.stdout)
    if not created_id:
        return
    context.last_created_id = created_id
    try:
        data = json.loads(result.stdout.strip())
        if 'full_path' in data:
            if not hasattr(context, 'tickets'):
                context.tickets = {}
            context.tickets[created_id] = Path(data['full_path'])
    except (json.JSONDecodeError, KeyError):
        pass


def _run_command(context, command, env_override=None):
    """DRY helper that consolidates the common subprocess execution pattern.

    Replaces 'change_log ' prefix with actual script path.
    Stores stdout/stderr/returncode on context.
    Calls _track_created_entry for create commands.
    """
    command = command.replace('\\"', '"')
    script = get_script(context)
    cmd = command.replace('change_log ', f'{script} ', 1)

    cwd = getattr(context, 'working_dir', context.test_dir)

    env = os.environ.copy()
    if env_override:
        env.update(env_override)

    result = subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        env=env
    )

    context.result = result
    context.stdout = result.stdout.strip()
    context.stderr = result.stderr.strip()
    context.returncode = result.returncode
    context.last_command = command

    _track_created_entry(context, command, result)


# ============================================================================
# Given Steps
# ============================================================================

@given(r'a clean changelog directory')
def step_clean_changelog_directory(context):
    """Ensure we start with a clean change_log directory."""
    changelog_dir = Path(context.test_dir) / 'change_log'
    if changelog_dir.exists():
        import shutil
        shutil.rmtree(changelog_dir)
    changelog_dir.mkdir(parents=True, exist_ok=True)


@given(r'the changelog directory does not exist')
def step_changelog_dir_not_exist(context):
    """Ensure change_log directory does not exist."""
    changelog_dir = Path(context.test_dir) / 'change_log'
    if changelog_dir.exists():
        import shutil
        shutil.rmtree(changelog_dir)


@given(r'a changelog entry exists with ID "(?P<entry_id>[^"]+)" and title "(?P<title>[^"]+)" with impact (?P<impact>\d+)')
def step_entry_exists_with_impact(context, entry_id, title, impact):
    """Create a changelog entry with given ID, title, and impact."""
    create_entry(context, entry_id, title, impact=int(impact))


@given(r'a changelog entry exists with ID "(?P<entry_id>[^"]+)" and title "(?P<title>[^"]+)" with type "(?P<entry_type>[^"]+)"')
def step_entry_exists_with_type(context, entry_id, title, entry_type):
    """Create a changelog entry with given ID, title, and type."""
    create_entry(context, entry_id, title, entry_type=entry_type)


@given(r'a changelog entry exists with ID "(?P<entry_id>[^"]+)" and title "(?P<title>[^"]+)"')
def step_entry_exists(context, entry_id, title):
    """Create a changelog entry with given ID and title (basic, no extra params)."""
    create_entry(context, entry_id, title)


@given(r'entry "(?P<entry_id>[^"]+)" has a notes section')
def step_entry_has_notes(context, entry_id):
    """Ensure entry has a notes section."""
    entry_path = find_entry_file(context, entry_id)
    content = entry_path.read_text()
    if '## Notes' not in content:
        content += '\n## Notes\n'
        entry_path.write_text(content)


@given(r'I am in subdirectory "(?P<subdir>[^"]+)"')
def step_in_subdirectory(context, subdir):
    """Change to a subdirectory (creating it if needed)."""
    subdir_path = Path(context.test_dir) / subdir
    subdir_path.mkdir(parents=True, exist_ok=True)
    context.working_dir = str(subdir_path)


@given(r'a separate changelog directory exists at "(?P<dir_path>[^"]+)" with entry "(?P<entry_id>[^"]+)" titled "(?P<title>[^"]+)"')
def step_separate_changelog_dir(context, dir_path, entry_id, title):
    """Create a separate changelog directory with an entry."""
    changelog_dir = Path(context.test_dir) / dir_path
    changelog_dir.mkdir(parents=True, exist_ok=True)

    filename = '2024-01-01_00-00-00Z.md'
    entry_path = changelog_dir / filename

    escaped_title = title.replace('"', '\\"')
    content = f'''---
id: {entry_id}
title: "{escaped_title}"
created_iso: 2024-01-01T00:00:00Z
type: default
impact: 3
---

'''
    entry_path.write_text(content)


@given(r'the test directory is a git repository')
def step_test_dir_is_git_repo(context):
    """Initialize a git repository in the test directory."""
    subprocess.run(
        ['git', 'init'],
        cwd=context.test_dir,
        capture_output=True,
        text=True
    )


# ============================================================================
# When Steps
# ============================================================================

# NOTE: More specific step patterns MUST be defined BEFORE the generic 'I run "X"'
# because behave regex matchers try steps in definition order.

@when(r'I run "(?P<command>(?:[^"\\]|\\.)+)" in non-TTY mode')
def step_run_command_non_tty(context, command):
    """Run a command simulating non-TTY mode."""
    _run_command(context, command)


@when(r'I run "(?P<command>(?:[^"\\]|\\.)+)" with no stdin')
def step_run_command_no_stdin(context, command):
    """Run a command with stdin closed."""
    _run_command(context, command)


@when(r'I run "(?P<command>(?:[^"\\]|\\.)+)" with CHANGE_LOG_DIR set to "(?P<changelog_dir>[^"]+)"')
def step_run_command_with_env(context, command, changelog_dir):
    """Run a change_log CLI command with custom CHANGE_LOG_DIR."""
    resolved_path = str(Path(context.test_dir) / changelog_dir)
    _run_command(context, command, env_override={'CHANGE_LOG_DIR': resolved_path})


@when(r'I run "(?P<command>(?:[^"\\]|\\.)+)"')
def step_run_command(context, command):
    """Run a change_log CLI command (generic catch-all)."""
    _run_command(context, command)


@when(r'I pipe "(?P<input_text>[^"]+)" to "(?P<command>(?:[^"\\]|\\.)+)"')
def step_pipe_to_command(context, input_text, command):
    """Pipe text input to a command via stdin."""
    command = command.replace('\\"', '"')
    script = get_script(context)
    cmd = command.replace('change_log ', f'{script} ', 1)

    cwd = getattr(context, 'working_dir', context.test_dir)

    result = subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        capture_output=True,
        text=True,
        input=input_text
    )

    context.result = result
    context.stdout = result.stdout.strip()
    context.stderr = result.stderr.strip()
    context.returncode = result.returncode
    context.last_command = command

    _track_created_entry(context, command, result)


# ============================================================================
# Then Steps
# ============================================================================

@then(r'the command should succeed')
def step_command_succeed(context):
    """Assert command returned exit code 0."""
    assert context.returncode == 0, \
        f"Command failed with exit code {context.returncode}\nstdout: {context.stdout}\nstderr: {context.stderr}"


@then(r'the command should fail')
def step_command_fail(context):
    """Assert command returned non-zero exit code."""
    assert context.returncode != 0, \
        f"Command succeeded but was expected to fail\nstdout: {context.stdout}"


@then(r'the output should be "(?P<expected>[^"]*)"')
def step_output_equals(context, expected):
    """Assert output exactly matches expected string."""
    actual = context.stdout
    assert actual == expected, f"Expected '{expected}' but got '{actual}'"


@then(r'the output should be empty')
def step_output_empty(context):
    """Assert output is empty."""
    assert context.stdout == '', f"Expected empty output but got: {context.stdout}"


@then(r'the output should contain "(?P<text>[^"]+)"')
def step_output_contains(context, text):
    """Assert output (stdout + stderr) contains text."""
    output = context.stdout + context.stderr
    assert text in output, f"Expected output to contain '{text}'\nActual output: {output}"


@then(r'the output should not contain "(?P<text>[^"]+)"')
def step_output_not_contains(context, text):
    """Assert output does not contain text."""
    output = context.stdout + context.stderr
    assert text not in output, f"Expected output to NOT contain '{text}'\nActual output: {output}"


@then(r'the output should be valid JSON with an id field')
def step_output_valid_json_with_id(context):
    """Assert output is valid JSON containing an id field."""
    try:
        data = json.loads(context.stdout)
    except json.JSONDecodeError as e:
        raise AssertionError(f"Output is not valid JSON: {context.stdout}\nError: {e}")
    assert 'id' in data, f"JSON output missing 'id' field\nData: {data}"


@then(r'the output should match an entry ID pattern')
def step_output_matches_entry_id_pattern(context):
    """Assert output is valid JSON from create command with id field."""
    try:
        data = json.loads(context.stdout)
    except json.JSONDecodeError as e:
        raise AssertionError(f"Output is not valid JSON: {context.stdout}\nError: {e}")
    assert 'id' in data, f"JSON output missing 'id' field\nData: {data}"
    assert isinstance(data['id'], str) and len(data['id']) > 0, \
        f"JSON 'id' field is not a non-empty string: {data['id']}"


@then(r'the output should match pattern "(?P<pattern>[^"]+)"')
def step_output_matches_pattern(context, pattern):
    """Assert output matches regex pattern."""
    assert re.search(pattern, context.stdout), \
        f"Output does not match pattern '{pattern}'\nActual output: {context.stdout}"


@then(r'the output should be valid JSONL')
def step_output_valid_jsonl(context):
    """Assert output is valid JSON Lines format."""
    lines = context.stdout.strip().split('\n')
    for line in lines:
        if line.strip():
            try:
                json.loads(line)
            except json.JSONDecodeError as e:
                raise AssertionError(f"Invalid JSONL line: {line}\nError: {e}")


@then(r'the JSONL output should have field "(?P<field>[^"]+)"')
def step_jsonl_has_field(context, field):
    """Assert JSONL output has a specific field."""
    lines = context.stdout.strip().split('\n')
    assert lines, "No JSONL output"

    for line in lines:
        if line.strip():
            data = json.loads(line)
            assert field in data, f"Field '{field}' not found in JSONL\nData: {data}"
            break


@then(r'every JSONL line should have field "(?P<field>[^"]+)"')
def step_every_jsonl_line_has_field(context, field):
    """Assert every JSONL line has a specific field."""
    lines = context.stdout.strip().split('\n')
    assert lines and lines[0].strip(), "No JSONL output"

    for line in lines:
        if line.strip():
            data = json.loads(line)
            assert field in data, f"Field '{field}' not found in JSONL line\nData: {data}"


@then(r'the JSONL output should have numeric field "(?P<field>[^"]+)"')
def step_jsonl_has_numeric_field(context, field):
    """Assert JSONL output has a specific field with numeric value."""
    lines = context.stdout.strip().split('\n')
    assert lines, "No JSONL output"

    for line in lines:
        if line.strip():
            data = json.loads(line)
            assert field in data, f"Field '{field}' not found in JSONL\nData: {data}"
            assert isinstance(data[field], (int, float)), \
                f"Field '{field}' is not numeric: {type(data[field]).__name__} = {data[field]}"
            break


@then(r'the output line (?P<line_num>\d+) should contain "(?P<text>[^"]+)"')
def step_output_line_contains(context, line_num, text):
    """Assert specific line of output contains text."""
    line_num = int(line_num)
    lines = context.stdout.split('\n')
    assert len(lines) >= line_num, \
        f"Output has only {len(lines)} lines, expected at least {line_num}"
    line = lines[line_num - 1]
    assert text in line, f"Line {line_num} does not contain '{text}'\nLine: {line}"


@then(r'the output line count should be (?P<count>\d+)')
def step_output_line_count(context, count):
    """Assert output has specific number of lines."""
    count = int(count)
    lines = [l for l in context.stdout.split('\n') if l.strip()]
    assert len(lines) == count, \
        f"Expected {count} lines but got {len(lines)}\nOutput: {context.stdout}"


@then(r'the changelog directory should exist')
def step_changelog_dir_exists(context):
    """Assert change_log directory exists."""
    changelog_dir = Path(context.test_dir) / 'change_log'
    assert changelog_dir.exists(), f"change_log directory does not exist at {changelog_dir}"


@then(r'a entry file should exist with title "(?P<title>[^"]+)"')
def step_entry_file_exists_with_title(context, title):
    """Assert an entry file exists with given title in frontmatter."""
    entry_id = context.last_created_id
    entry_path = find_entry_file(context, entry_id)

    assert entry_path.exists(), f"Entry file {entry_path} does not exist"
    content = entry_path.read_text()
    assert re.search(rf'^title:\s*"?{re.escape(title)}"?\s*$', content, re.MULTILINE), \
        f"Entry does not have title '{title}' in frontmatter\nContent: {content}"


@then(r'the created entry should contain "(?P<text>[^"]+)"')
def step_created_entry_contains(context, text):
    """Assert the most recently created entry contains text."""
    entry_id = context.last_created_id
    entry_path = find_entry_file(context, entry_id)
    content = entry_path.read_text()
    assert text in content, f"Entry does not contain '{text}'\nContent: {content}"


@then(r'the created entry should not contain "(?P<text>[^"]+)"')
def step_created_entry_not_contains(context, text):
    """Assert the most recently created entry does NOT contain text."""
    entry_id = context.last_created_id
    entry_path = find_entry_file(context, entry_id)
    content = entry_path.read_text()
    assert text not in content, f"Entry should not contain '{text}'\nContent: {content}"


@then(r'the created entry should have field "(?P<field>[^"]+)" with value "(?P<value>[^"]+)"')
def step_created_entry_has_field(context, field, value):
    """Assert the most recently created entry has a field with value."""
    entry_id = context.last_created_id
    entry_path = find_entry_file(context, entry_id)
    content = entry_path.read_text()

    pattern = rf'^{re.escape(field)}:\s*(.+)$'
    match = re.search(pattern, content, re.MULTILINE)
    assert match, f"Field '{field}' not found in entry\nContent: {content}"
    actual = match.group(1).strip()
    # Strip surrounding quotes for comparison (title is stored as "value")
    actual_unquoted = actual.strip('"')
    assert actual == value or actual_unquoted == value, \
        f"Field '{field}' has value '{actual}', expected '{value}'"


@then(r'the created entry should have a valid created_iso timestamp')
def step_created_entry_has_timestamp(context):
    """Assert the created entry has a valid created_iso timestamp."""
    entry_id = context.last_created_id
    entry_path = find_entry_file(context, entry_id)
    content = entry_path.read_text()

    pattern = r'^created_iso:\s*\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z'
    assert re.search(pattern, content, re.MULTILINE), \
        f"No valid created_iso timestamp found\nContent: {content}"


@then(r'entry "(?P<entry_id>[^"]+)" should contain "(?P<text>[^"]+)"')
def step_entry_contains(context, entry_id, text):
    """Assert entry file contains text."""
    entry_path = find_entry_file(context, entry_id)
    content = entry_path.read_text()
    assert text in content, f"Entry does not contain '{text}'\nContent: {content}"


@then(r'entry "(?P<entry_id>[^"]+)" should contain a timestamp in notes')
def step_entry_has_timestamp_in_notes(context, entry_id):
    """Assert entry has a timestamp in notes section."""
    entry_path = find_entry_file(context, entry_id)
    content = entry_path.read_text()

    pattern = r'\*\*\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\*\*'
    assert re.search(pattern, content), \
        f"No timestamp found in notes\nContent: {content}"


@then(r'a file named "(?P<filename>[^"]+)" should exist in changelog directory')
def step_file_named_exists_in_changelog(context, filename):
    """Assert a specific filename exists in change_log/ directory."""
    changelog_dir = Path(context.test_dir) / 'change_log'
    file_path = changelog_dir / filename
    assert file_path.exists(), \
        f"File {filename} does not exist in change_log/\nFiles present: {[f.name for f in changelog_dir.glob('*.md')]}"
