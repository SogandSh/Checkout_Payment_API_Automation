*** Settings ***
Resource    ../apis/payment_api.robot

*** Keywords ***
Given payment response file "${file}"
    Load Payment Response    ${file}

When I validate transport status
    Validate Transport Status

When I validate schema
    Validate Schema

And I validate business rules
    Validate Business Rules

Then validation should pass
    Assert Validation Passed

Then validation should fail
    Assert Validation Failed
