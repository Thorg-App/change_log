Feature: Changelog Listing
  As a user
  I want to list changelog entries
  So that I can see recent changes in my project

  Background:
    Given a clean changelog directory

  Scenario: List all entries
    Given a changelog entry exists with ID "list-0001" and title "First entry"
    And a changelog entry exists with ID "list-0002" and title "Second entry"
    When I run "change_log ls"
    Then the command should succeed
    And the output should contain "list-000"
    And the output should contain "list-000"

  Scenario: List command alias works
    Given a changelog entry exists with ID "list-0001" and title "First entry"
    When I run "change_log list"
    Then the command should succeed
    And the output should contain "list-000"

  Scenario: List shows correct format
    Given a changelog entry exists with ID "fmt-00001" and title "Format test" with impact 4
    When I run "change_log ls"
    Then the command should succeed
    And the output should match pattern "[a-z0-9-]{8}\s+\[I4\]\[default\]\s+Format test"

  Scenario: List with no entries returns nothing
    When I run "change_log ls"
    Then the output should be empty

  Scenario: List with --limit
    Given a changelog entry exists with ID "lim-00001" and title "Entry one"
    And a changelog entry exists with ID "lim-00002" and title "Entry two"
    And a changelog entry exists with ID "lim-00003" and title "Entry three"
    When I run "change_log ls --limit=2"
    Then the command should succeed
    And the output line count should be 2

  Scenario: List shows most recent first
    Given a changelog entry exists with ID "order-aaa" and title "Older entry"
    And a changelog entry exists with ID "order-bbb" and title "Newer entry"
    When I run "change_log ls"
    Then the command should succeed
    And the output line 1 should contain "order-bb"
    And the output line 2 should contain "order-aa"

  Scenario: List shows impact level in output
    Given a changelog entry exists with ID "imp-00001" and title "Impact entry" with impact 4
    When I run "change_log ls"
    Then the command should succeed
    And the output should contain "[I4]"
