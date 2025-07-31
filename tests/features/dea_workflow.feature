Feature: DEA Controlled Substance Workflow
  As a compliance officer
  I want to ensure proper DEA documentation for controlled substances
  So that we meet federal regulatory requirements

  Rule: DEA fields are required for controlled substances
    Scenario: DEA number validation
      Given the user has materials requiring DEA oversight
      When the user enters DEA number "AB1234567"
      Then the system should accept the DEA number
      And the DEA workflow should be enabled

    Scenario: Invalid DEA number format
      Given the user is on the DEA information step
      When the user enters DEA number "123456789"
      Then the system should show error "DEA number must be 2 letters followed by 7 digits"

    Scenario: Missing CSSR URI for controlled substances
      Given the user has entered valid DEA number "XY9876543"
      When the user leaves CSSR Inbound URI empty
      Then the system should show error "CSSR Inbound URI is required for controlled substances"

  Rule: Substance schedule validation
    Scenario: Valid substance schedule selection
      Given the user has entered valid DEA information
      When the user selects substance schedule "II"
      Then the system should accept the selection
      And additional compliance warnings should be displayed

    Scenario: Schedule I substances require special handling
      Given the user selects substance schedule "I"
      When the user attempts to proceed
      Then the system should show warning "Schedule I substances require additional approvals"
      And the system should require supervisor override

  Rule: DEA workflow is conditional
    Scenario: Standard materials skip DEA step
      Given the user has only standard (non-controlled) materials
      When the user completes the materials step
      Then the system should skip the DEA information step
      And proceed directly to shipping & turnaround

    Scenario: Mixed materials trigger DEA workflow
      Given the user has both standard and controlled materials
      When the user completes the materials step
      Then the system should proceed to DEA information step
      And mark controlled materials with appropriate indicators
