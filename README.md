# Checkout Payment API Automation

[![Robot Tests](https://github.com/SogandSh/Checkout_Payment_API_Automation/actions/workflows/robot-tests.yml/badge.svg)](https://github.com/SogandSh/Checkout_Payment_API_Automation/actions)

## Overview

This project contains an automated API validation suite for the Checkout Payment endpoint of an e-commerce marketplace.

The purpose of this automation suite is to validate:

- Response schema correctness
- Critical business rules (R1–R7)
- Negative and edge cases
- Clear and actionable failure diagnostics

The solution is implemented using **Robot Framework** with a clean layered BDD architecture.

As permitted by the task requirements, a JSON-based simulation approach is used instead of a real HTTP server.

---

## Project Structure

Checkout_Payment_API_Automation/     
│      
├──  features/  #  BDD scenarios  
├──  steps/  #  Step definitions  
├──  apis/  #  Validation  
├──  testdata/  #  Sample API response JSON files  
├──  requirements.txt  
└──  README.md

### Layer Responsibilities

**features/**  
Contains only BDD-style scenarios.  
No parsing, HTTP logic, or assertions are implemented here.

**steps/**  
Maps high-level BDD steps to validation keywords.

**apis/**  
Contains the validation engine:
- Schema validation
- Business rule enforcement
- Error aggregation
- Fail-fast logic

**testdata/**  
Contains sample API responses representing positive and negative scenarios.

---

## Implemented Business Rules

### R1 – Schema Validation
- `payment_methods` must exist and be an array.
- Each payment method must contain required fields:
  - `id`
  - `type`
  - `title`
  - `is_clickable`
- Type validation is enforced.

### R2 – Clickability Rule
- A payment method is selectable only if `is_clickable = true`.

### R3 – Wallet Rule

The original requirement states:

> `is_wallet` must be false if type is not wallet.

However, the provided API schema does not include an `is_wallet` field.

Assumption made:
- Wallet identification is derived directly from `type = wallet`.
- Since the field does not exist in the schema, no additional `is_wallet` validation is implemented.
- This requirement–schema inconsistency is intentionally documented.

### R4 – BNPL Options Rule
- If `type = bnpl`, the `options` field must exist and be an array.
- If BNPL is clickable, options cannot be empty.

### R5 – Option Eligibility Rule
An option is eligible only if:
- `is_active = true`
- `credit > 0`

### R6 – Default Option Rule
If at least one eligible option exists:
- Exactly one eligible option must have `is_default = true`.

### R7 – Price Type Rule
`price_type` must be one of:
- `CASH_PRICE`
- `CREDIT_PRICE`

Case-sensitive validation is enforced.

---

## Test Scenarios

| Scenario | Description | Expected Result |
|----------|-------------|----------------|
| S1 | Happy path | All validations pass |
| S2 | BNPL blocked | Non-clickable BNPL handled correctly |
| S3 | Insufficient credit | Ineligible option handled correctly |
| S4 | Non-active option | Ineligible option handled correctly |
| S5 | Multiple default options | Validation fails (R6 violation) |
| S6 | Missing required field | Schema validation fails |
| S7 | Wrong field type | Type validation fails |
| S8 | Non-success status | Fail-fast when status != 200 |

---

## Error Handling Strategy

- All validation errors are aggregated into a single error list.
- Tests fail with clear and descriptive diagnostic messages.
- Fail-fast behavior is applied for:
  - Missing critical fields
  - Invalid response status

This prevents silent regressions and improves debugging clarity.

---

## How to Run

### Install dependencies

pip install -r requirements.txt

### Execute tests

robot -d reports features/

### View reports

Open:

- reports/report.html
- reports/log.html

---

## Design Decisions

- JSON simulation was chosen instead of a fake HTTP server to keep focus on validation logic.
- Strict separation of concerns was enforced:
  - BDD layer contains no technical logic.
  - Validation engine is isolated in `apis/`.
- Defensive validation prevents silent regressions.
- The architecture is extensible and can easily support real HTTP calls in the future.

---

## Assumptions

- Wallet behavior is determined solely by `type = wallet`.
- Pricing correctness beyond presence/type validation is out of scope.
- HTTP errors are simulated using the `status` field in JSON responses.

---

## Summary

This automation suite validates:

- Structural correctness of payment responses
- Enforcement of critical business rules
- Coverage of positive and negative cases
- Clear and maintainable test architecture

The solution is structured, scalable, and suitable for CI integration.
