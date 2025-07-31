Feature: Facility-Specific Constraints
  As a facility manager
  I want to enforce facility-specific capabilities and restrictions
  So that orders are routed to appropriate processing locations

  Rule: Lewisville freezer capacity constraints
    Scenario: Frozen materials at Lewisville trigger capacity warning
      Given the user selects facility "Lewisville"
      And the user selects environmental condition "Frozen"
      When the user adds materials with total volume > 50 cubic feet
      Then the system should show warning "Lewisville freezer capacity limited - contact facility manager"
      And the system should suggest "Fremont" as alternative

    Scenario: Frozen materials under capacity limit
      Given the user selects facility "Lewisville"
      And the user selects environmental condition "Frozen"
      When the user adds materials with total volume ≤ 50 cubic feet
      Then the system should accept the configuration
      And no capacity warnings should be displayed

  Rule: Fremont facility capabilities
    Scenario: Fremont accepts all environmental conditions
      Given the user selects facility "Fremont"
      When the user selects environmental condition "<condition>"
      Then the system should accept the selection
      Examples:
        | condition     |
        | Ambient       |
        | Frozen        |
        | Refrigerated  |

    Scenario: Fremont high-dose capability
      Given the user selects facility "Fremont"
      When the user enters target dose "100"
      Then the system should accept the high dose
      And show estimated processing time

  Rule: Expedited turnaround restrictions
    Scenario: Lewisville expedited service limitations
      Given the user selects facility "Lewisville"
      And the user selects turnaround "Expedited"
      When the user selects environmental condition "Frozen"
      Then the system should show warning "Expedited frozen processing not available at Lewisville"
      And suggest "Standard" turnaround or "Fremont" facility

    Scenario: Fremont supports all expedited combinations
      Given the user selects facility "Fremont"
      When the user selects turnaround "Expedited"
      And the user selects any environmental condition
      Then the system should accept the configuration
      And display expedited pricing
