Feature: Changelog Notes
  As a user
  I want to add notes to changelog entries
  So that I can track additional context and updates

  Background:
    Given a clean changelog directory
    And a changelog entry exists with ID "note-0001" and title "Test entry"

  Scenario: Add a note to entry
    When I run "change_log add-note note-0001 'This is my note'"
    Then the command should succeed
    And the output should be "Note added to note-0001"
    And entry "note-0001" should contain "## Notes"
    And entry "note-0001" should contain "This is my note"

  Scenario: Note has timestamp
    When I run "change_log add-note note-0001 'Timestamped note'"
    Then the command should succeed
    And entry "note-0001" should contain a timestamp in notes

  Scenario: Add multiple notes
    When I run "change_log add-note note-0001 'First note'"
    And I run "change_log add-note note-0001 'Second note'"
    Then entry "note-0001" should contain "First note"
    And entry "note-0001" should contain "Second note"

  Scenario: Add note to entry that already has notes section
    Given entry "note-0001" has a notes section
    When I run "change_log add-note note-0001 'Additional note'"
    Then the command should succeed
    And entry "note-0001" should contain "Additional note"

  Scenario: Add note with empty string adds timestamp-only note
    When I run "change_log add-note note-0001 ''"
    Then the command should succeed
    And the output should be "Note added to note-0001"
    And entry "note-0001" should contain "## Notes"

  Scenario: Add note to non-existent entry
    When I run "change_log add-note nonexistent 'My note'"
    Then the command should fail
    And the output should contain "Error: entry 'nonexistent' not found"

  Scenario: Add note via piped stdin
    When I pipe "Piped note content" to "change_log add-note note-0001"
    Then the command should succeed
    And entry "note-0001" should contain "Piped note content"

