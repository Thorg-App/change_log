Feature: Changelog Directory Resolution
  As a user
  I want change_log to find the changelog directory by walking parent directories
  So that I can run commands from any subdirectory of my project

  Background:
    Given a clean changelog directory

  Scenario: Find changelog in current directory
    Given a changelog entry exists with ID "test-0001" and title "Test entry"
    When I run "change_log ls"
    Then the command should succeed
    And the output should contain "test-000"

  Scenario: Find changelog in parent directory
    Given a changelog entry exists with ID "test-0001" and title "Test entry"
    And I am in subdirectory "src/components"
    When I run "change_log ls"
    Then the command should succeed
    And the output should contain "test-000"

  Scenario: Find changelog in grandparent directory
    Given a changelog entry exists with ID "test-0001" and title "Test entry"
    And I am in subdirectory "src/components/ui"
    When I run "change_log ls"
    Then the command should succeed
    And the output should contain "test-000"

  Scenario: CHANGE_LOG_DIR env var takes priority
    Given a changelog entry exists with ID "parent-001" and title "Parent entry"
    And a separate changelog directory exists at "other-changelog" with entry "other-001" titled "Other entry"
    And I am in subdirectory "src"
    When I run "change_log ls" with CHANGE_LOG_DIR set to "other-changelog"
    Then the command should succeed
    And the output should contain "other-00"
    And the output should not contain "parent-0"

  Scenario: Show command works from subdirectory
    Given a changelog entry exists with ID "test-0001" and title "Test entry"
    And I am in subdirectory "src"
    When I run "change_log show test-0001"
    Then the command should succeed
    And the output should contain "id: test-0001"

  Scenario: Help command works without changelog directory
    Given the changelog directory does not exist
    When I run "change_log help"
    Then the command should succeed
    And the output should contain "git-backed changelog"

  Scenario: Error when no changelog directory for read command
    Given the changelog directory does not exist
    When I run "change_log ls"
    Then the command should fail
    And the output should contain "no .change_log directory found"

  Scenario: Error when no changelog directory in any parent
    Given the changelog directory does not exist
    And I am in subdirectory "orphan/deep/path"
    When I run "change_log ls"
    Then the command should fail
    And the output should contain "no .change_log directory found"

  Scenario: Unknown command shows helpful error
    When I run "change_log foo"
    Then the command should fail
    And the output should contain "Unknown command: foo"

  Scenario: Create auto-creates changelog directory at git root
    Given the changelog directory does not exist
    And the test directory is a git repository
    When I run "change_log create 'First entry' --impact 1"
    Then the command should succeed
    And the changelog directory should exist
