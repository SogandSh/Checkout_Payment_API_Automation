*** Settings ***
Documentation    Checkout Payment API: schema, business rules (R1–R7), and negative/edge cases.
...              All JSON parsing and assertions are in steps/ and apis/.
Resource         ../steps/payment_steps.robot

*** Test Cases ***
S1 Happy path
    Given payment response file "happy.json"
    When I validate schema
    And I validate business rules
    Then validation should pass

S2 BNPL blocked
    Given payment response file "bnpl_blocked.json"
    When I validate schema
    And I validate business rules
    Then validation should pass

S3 Insufficient credit
    Given payment response file "insufficient_credit.json"
    When I validate schema
    And I validate business rules
    Then validation should pass

S4 Non-active option
    Given payment response file "non_active_option.json"
    When I validate schema
    And I validate business rules
    Then validation should pass

S5 Default option invalid (multiple defaults among eligible)
    Given payment response file "invalid_default.json"
    When I validate schema
    And I validate business rules
    Then validation should fail

S6 Missing required field
    Given payment response file "missing_field.json"
    When I validate schema
    Then validation should fail

S7 Wrong type
    Given payment response file "wrong_type.json"
    When I validate schema
    Then validation should fail

S8 S8 Non-success body status (status != 200)
    Given payment response file "http_500.json"
    When I validate transport status
    Then validation should fail
