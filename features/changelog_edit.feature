Feature: Changelog Edit
  As a user
  I want to edit changelog entries in my editor
  So that I can make detailed changes easily

  Background:
    Given a clean changelog directory
    And a changelog entry exists with ID "edit-0001" and title "Editable entry"

  Scenario: Edit in non-TTY mode shows file path
    When I run "change_log edit edit-0001" in non-TTY mode
    Then the command should succeed
    And the output should contain "Edit entry file:"
    And the output should contain "_change_log/"

  Scenario: Edit non-existent entry
    When I run "change_log edit nonexistent"
    Then the command should fail
    And the output should contain "Error: entry 'nonexistent' not found"

