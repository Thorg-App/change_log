Feature: Changelog Entry Creation
  As a user
  I want to create changelog entries with various options
  So that I can track changes in my project

  Background:
    Given a clean changelog directory

  Scenario: Create a basic entry with title
    When I run "change_log create 'My first entry' --impact 3"
    Then the command should succeed
    And the output should be valid JSON with an id field
    And a entry file should exist with title "My first entry"

  Scenario: Create an entry with default title
    When I run "change_log create --impact 3"
    Then the command should succeed
    And the output should be valid JSON with an id field
    And a entry file should exist with title "Untitled"

  Scenario: Create fails without --impact
    When I run "change_log create 'No impact'"
    Then the command should fail
    And the output should contain "Error: --impact is required (1-5)"

  Scenario: Create fails with impact 0
    When I run "change_log create 'Bad impact' --impact 0"
    Then the command should fail
    And the output should contain "Error: --impact must be 1-5"

  Scenario: Create fails with impact 6
    When I run "change_log create 'Bad impact' --impact 6"
    Then the command should fail
    And the output should contain "Error: --impact must be 1-5"

  Scenario: Create fails with non-numeric impact
    When I run "change_log create 'Bad impact' --impact high"
    Then the command should fail
    And the output should contain "Error: --impact must be 1-5"

  Scenario: Create succeeds with impact 1 boundary
    When I run "change_log create 'Low impact' --impact 1"
    Then the command should succeed

  Scenario: Create succeeds with impact 5 boundary
    When I run "change_log create 'High impact' --impact 5"
    Then the command should succeed

  Scenario: Impact stored as numeric in frontmatter
    When I run "change_log create 'Impact test' --impact 3"
    Then the command should succeed
    And the created entry should have field "impact" with value "3"

  Scenario: Default type is default
    When I run "change_log create 'Default type' --impact 3"
    Then the command should succeed
    And the created entry should have field "type" with value "default"

  Scenario: Create with valid type feature
    When I run "change_log create 'Feature entry' --impact 3 -t feature"
    Then the command should succeed
    And the created entry should have field "type" with value "feature"

  Scenario: Create fails with invalid type
    When I run "change_log create 'Bad type' --impact 3 -t invalid_type"
    Then the command should fail
    And the output should contain "Error: invalid type"

  Scenario: Create with --desc
    When I run "change_log create 'Described entry' --impact 3 --desc 'A description'"
    Then the command should succeed
    And the created entry should contain "desc:"

  Scenario: Create without --desc omits desc field
    When I run "change_log create 'No desc' --impact 3"
    Then the command should succeed
    And the created entry should not contain "desc:"

  Scenario: Create with --tags
    When I run "change_log create 'Tagged entry' --impact 3 --tags ui,backend"
    Then the command should succeed
    And the created entry should contain "tags: [ui, backend]"

  Scenario: Create with --dirs
    When I run "change_log create 'Dir entry' --impact 3 --dirs src/api,src/ui"
    Then the command should succeed
    And the created entry should contain "dirs: [src/api, src/ui]"

  Scenario: Create with --ap key=value
    When I run "change_log create 'AP entry' --impact 3 --ap anchor1=value1"
    Then the command should succeed
    And the created entry should contain "ap:"
    And the created entry should contain "  anchor1: value1"

  Scenario: Create without --ap omits ap field
    When I run "change_log create 'No AP' --impact 3"
    Then the command should succeed
    And the created entry should not contain "ap:"

  Scenario: --ap rejects missing equals sign
    When I run "change_log create 'Bad AP' --impact 3 --ap badformat"
    Then the command should fail
    And the output should contain "Error: --ap requires key=value format"

  Scenario: Create with --note-id
    When I run "change_log create 'NoteID entry' --impact 3 --note-id ref1=abc123"
    Then the command should succeed
    And the created entry should contain "note_id:"
    And the created entry should contain "  ref1: abc123"

  Scenario: --note-id rejects missing equals sign
    When I run "change_log create 'Bad NoteID' --impact 3 --note-id badformat"
    Then the command should fail
    And the output should contain "Error: --note-id requires key=value format"

  Scenario: Created entry has timestamp-based filename
    When I run "change_log create 'Timestamp file' --impact 3"
    Then the command should succeed
    And the output should match pattern "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}Z\.md"

  Scenario: Created entry has valid created_iso timestamp
    When I run "change_log create 'Timestamped' --impact 3"
    Then the command should succeed
    And the created entry should have a valid created_iso timestamp

  Scenario: Create outputs JSONL with expected fields
    When I run "change_log create 'JSON output test' --impact 3"
    Then the command should succeed
    And the output should be valid JSONL
    And the JSONL output should have field "id"
    And the JSONL output should have field "title"
    And the JSONL output should have field "type"
    And the JSONL output should have field "impact"
    And the JSONL output should have field "full_path"

  Scenario: Title stored in frontmatter
    When I run "change_log create 'Frontmatter Title' --impact 3"
    Then the command should succeed
    And the created entry should have field "title" with value "Frontmatter Title"

  Scenario: Create with --author flag
    When I run "change_log create 'Author test' --impact 3 -a 'Test Author'"
    Then the command should succeed
    And the created entry should have field "author" with value "Test Author"

  Scenario: Create with --details_in_md
    When I run "change_log create 'Details test' --impact 3 --details_in_md 'Detailed markdown body content'"
    Then the command should succeed
    And the created entry should contain "Detailed markdown body content"

  Scenario: Details visible via show command
    When I run "change_log create 'Show details test' --impact 3 --details_in_md 'Context and explanation here'"
    Then the command should succeed
    When I show the last created entry
    Then the command should succeed
    And the output should contain "Context and explanation here"
