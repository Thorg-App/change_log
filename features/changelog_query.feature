Feature: Changelog Query
  As a user
  I want to query changelog entries as JSONL
  So that I can process entry data programmatically

  Background:
    Given a clean changelog directory

  Scenario: Query all entries as JSONL
    Given a changelog entry exists with ID "query-001" and title "First entry"
    And a changelog entry exists with ID "query-002" and title "Second entry"
    When I run "change_log query"
    Then the command should succeed
    And the output should be valid JSONL
    And the output should contain "query-001"
    And the output should contain "query-002"

  Scenario: Query with jq filter by type
    Given a changelog entry exists with ID "query-001" and title "Feature entry" with type "feature"
    And a changelog entry exists with ID "query-002" and title "Default entry" with type "default"
    When I run "change_log query '.type == \"feature\"'"
    Then the command should succeed
    And the output should contain "query-001"
    And the output should not contain "query-002"

  Scenario: Query includes core fields
    Given a changelog entry exists with ID "query-001" and title "Full entry"
    When I run "change_log query"
    Then the command should succeed
    And the JSONL output should have field "id"
    And the JSONL output should have field "title"
    And the JSONL output should have field "created_iso"
    And the JSONL output should have field "type"
    And the JSONL output should have field "impact"

  Scenario: Query with no entries
    When I run "change_log query"
    Then the output should be empty

  Scenario: Query always includes full_path
    Given a changelog entry exists with ID "query-001" and title "Path entry"
    When I run "change_log query"
    Then the command should succeed
    And the output should be valid JSONL
    And every JSONL line should have field "full_path"

  Scenario: Query includes title field
    Given a changelog entry exists with ID "query-001" and title "Title test entry"
    When I run "change_log query"
    Then the command should succeed
    And the output should be valid JSONL
    And the JSONL output should have field "title"
    And the output should contain "Title test entry"

  Scenario: Query impact is numeric
    Given a changelog entry exists with ID "query-001" and title "Numeric test" with impact 4
    When I run "change_log query"
    Then the command should succeed
    And the JSONL output should have numeric field "impact"

  Scenario: Query outputs most recent first
    Given a changelog entry exists with ID "order-aaa" and title "Older entry"
    And a changelog entry exists with ID "order-bbb" and title "Newer entry"
    When I run "change_log query"
    Then the command should succeed
    And the output line 1 should contain "order-bbb"
    And the output line 2 should contain "order-aaa"

  Scenario: Query includes desc field when present
    When I run "change_log create 'Desc query test' --impact 3 --desc 'A test description'"
    And I run "change_log query"
    Then the command should succeed
    And the output should contain "desc"
    And the output should contain "A test description"

  Scenario: Query excludes details_in_md content
    When I run "change_log create 'Query exclude test' --impact 3 --details_in_md 'SECRET_DETAILS_TEXT'"
    And I run "change_log query"
    Then the command should succeed
    And the output should not contain "SECRET_DETAILS_TEXT"

  Scenario: Query does not leak body content when details contain markdown horizontal rule
    When I run "change_log create 'HR body test' --impact 2 --desc 'real desc' --details_in_md $'Some details\n\n---\n\nfake_field: leaked_value\nstatus: should_not_appear'"
    And I run "change_log query"
    Then the command should succeed
    And the output should contain "real desc"
    And the output should not contain "leaked_value"
    And the output should not contain "fake_field"
    And the output should not contain "should_not_appear"
