Feature: Changelog Show
  As a user
  I want to view changelog entry details
  So that I can see full information about an entry

  Background:
    Given a clean changelog directory

  Scenario: Show displays entry content
    Given a changelog entry exists with ID "show-001" and title "Test entry"
    When I run "change_log show show-001"
    Then the command should succeed
    And the output should contain "id: show-001"
    And the output should contain "title:"
    And the output should contain "Test entry"

  Scenario: Show displays frontmatter fields
    Given a changelog entry exists with ID "show-001" and title "Full entry"
    When I run "change_log show show-001"
    Then the command should succeed
    And the output should contain "type: default"
    And the output should contain "impact: 3"
    And the output should contain "created_iso:"

  Scenario: Show non-existent entry
    When I run "change_log show nonexistent"
    Then the command should fail
    And the output should contain "Error: entry 'nonexistent' not found"

  Scenario: Show with no arguments
    When I run "change_log show"
    Then the command should fail
    And the output should contain "Usage:"
