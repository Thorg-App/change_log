Feature: Changelog ID Resolution
  As a user
  I want to use partial entry IDs
  So that I can work faster without typing full IDs

  Background:
    Given a clean changelog directory

  Scenario: Exact ID match
    Given a changelog entry exists with ID "abc-1234" and title "Test entry"
    When I run "change_log show abc-1234"
    Then the command should succeed
    And the output should contain "id: abc-1234"

  Scenario: Partial ID match by suffix
    Given a changelog entry exists with ID "abc-1234" and title "Test entry"
    When I run "change_log show 1234"
    Then the command should succeed
    And the output should contain "id: abc-1234"

  Scenario: Partial ID match by prefix
    Given a changelog entry exists with ID "abc-1234" and title "Test entry"
    When I run "change_log show abc"
    Then the command should succeed
    And the output should contain "id: abc-1234"

  Scenario: Partial ID match by substring
    Given a changelog entry exists with ID "abc-1234" and title "Test entry"
    When I run "change_log show c-12"
    Then the command should succeed
    And the output should contain "id: abc-1234"

  Scenario: Ambiguous ID error
    Given a changelog entry exists with ID "abc-1234" and title "First entry"
    And a changelog entry exists with ID "abc-5678" and title "Second entry"
    When I run "change_log show abc"
    Then the command should fail
    And the output should contain "Error: ambiguous ID 'abc' matches multiple entries"

  Scenario: Non-existent ID error
    When I run "change_log show nonexistent"
    Then the command should fail
    And the output should contain "Error: entry 'nonexistent' not found"

  Scenario: Exact match takes precedence
    Given a changelog entry exists with ID "abc" and title "Short ID entry"
    And a changelog entry exists with ID "abc-1234" and title "Long ID entry"
    When I run "change_log show abc"
    Then the command should succeed
    And the output should contain "id: abc"
    And the output should contain "Short ID entry"

  Scenario: ID resolution works with add-note command
    Given a changelog entry exists with ID "test-9999" and title "Test entry"
    When I run "change_log add-note 9999 'test note'"
    Then the command should succeed
