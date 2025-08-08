Feature: Dose Range Validation
  As a quality control system
  I want to validate dose ranges based on PPS specifications
  So that processing parameters meet validated requirements

  Background:
    Given a PPS catalog with the following entries:
      | pps_code | description        | validated_dose | is_validated |
      | 12301    | Standard Protocol  | 25            | true         |
      | 12380    | R&D Protocol      | null          | false        |
      | VAL001   | Validated Process | 15            | true         |

  Rule: R&D orders use ±10% dose range
    Scenario: R&D PPS code allows 10% variance
      Given the user selects PPS code "12380"
      When the user enters target dose "30"
      Then the system should set dose range low to 27
      And the system should set dose range high to 33

    Scenario: R&D split dose calculation
      Given the user selects PPS code "12380"  
      When the user enters target dose "10+10+10"
      Then the system should set dose range low to 27
      And the system should set dose range high to 33

  Rule: Validated PPS requires exact dose range
    Scenario: Validated PPS enforces exact dose
      Given the user selects PPS code "12301"
      When the user enters dose range low 25
      Then the system should require dose range high to be 25
      And the system should block if dose range high is not 25

    Scenario: Validated PPS rejects variance
      Given the user selects PPS code "VAL001"
      When the user enters dose range low 14
      And the user enters dose range high 16
      Then the system should show error "Validated PPS requires exact dose range of 15 kGy"

  Rule: PPS validation occurs on field change
    Scenario: Real-time validation feedback
      Given the user is on the processing specifications step
      When the user enters PPS code "INVALID"
      Then the system should show error "PPS code not found in catalog"
      And the dose range fields should be disabled
