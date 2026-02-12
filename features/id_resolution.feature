Feature: Changelog ID Resolution
  As a user
  I want to look up entries by their ID
  So that I can reference specific changelog entries

  Background:
    Given a clean changelog directory

  Scenario: Exact ID match
    Given a changelog entry exists with ID "abc-1234" and title "Test entry"
    When I run "change_log show abc-1234"
    Then the command should succeed
    And the output should contain "id: abc-1234"

  Scenario: Non-existent ID error
    When I run "change_log show nonexistent"
    Then the command should fail
    And the output should contain "Error: entry 'nonexistent' not found"

  Scenario: Substring of ID does not match
    Given a changelog entry exists with ID "abc-1234" and title "Test entry"
    When I run "change_log show 1234"
    Then the command should fail
    And the output should contain "Error: entry '1234' not found"
