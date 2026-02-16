*** Settings ***
Library    JSONLibrary
Library    Collections
Library    OperatingSystem

*** Keywords ***
Load Payment Response
    [Arguments]    ${file}
    ${path}=    Join Path    ${CURDIR}    ..    testdata    ${file}
    Log    Loading test data: ${path}
    ${json}=    Load JSON From File    ${path}
    Set Suite Variable    ${RESPONSE}    ${json}
    ${errors}=    Create List
    Set Suite Variable    ${ERRORS}    ${errors}

Add Error
    [Arguments]    ${msg}
    Log    ERROR: ${msg}
    Append To List    ${ERRORS}    ${msg}

Assert Validation Passed
    ${count}=    Get Length    ${ERRORS}
    IF    ${count} > 0
        ${details}=    Catenate    SEPARATOR=\n-    @{ERRORS}
        Fail    Validation failed with ${count} error(s):\n- ${details}
    END

Assert Validation Failed
    ${count}=    Get Length    ${ERRORS}
    Run Keyword If    ${count} == 0    Fail    Expected validation to fail, but no errors were found.

Validate Transport Status
    Log    Validating body.status == 200
    ${has_status}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${RESPONSE}    status
    IF    not ${has_status}
        Add Error    Missing top-level field 'status'
        Return From Keyword
    END

    ${status}=    Get From Dictionary    ${RESPONSE}    status
    ${is_int}=    Evaluate    isinstance($status, int)
    IF    not ${is_int}
        Add Error    Type: top-level status must be int (got ${status})
        Return From Keyword
    END

    Run Keyword If    ${status} != 200    Add Error    Non-success body.status: expected 200 but got ${status}

Validate Schema
    Log    Validating R1: payment_methods + required fields + basic types
    ${has_pm}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${RESPONSE}    payment_methods
    IF    not ${has_pm}
        Add Error    R1: Missing top-level field 'payment_methods'
        Return From Keyword
    END

    ${methods}=    Get From Dictionary    ${RESPONSE}    payment_methods
    ${is_list}=    Evaluate    isinstance($methods, list)
    IF    not ${is_list}
        Add Error    R1: 'payment_methods' must be an array/list
        Return From Keyword
    END

    ${i}=    Set Variable    0
    FOR    ${m}    IN    @{methods}
        ${ok_id}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    id
        ${ok_type}=   Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    type
        ${ok_title}=  Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    title
        ${ok_click}=  Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    is_clickable

        Run Keyword If    not ${ok_id}     Add Error    R1: payment_methods[${i}] missing 'id'
        Run Keyword If    not ${ok_type}   Add Error    R1: payment_methods[${i}] missing 'type'
        Run Keyword If    not ${ok_title}  Add Error    R1: payment_methods[${i}] missing 'title'
        Run Keyword If    not ${ok_click}  Add Error    R1: payment_methods[${i}] missing 'is_clickable'

        IF    ${ok_id}
            ${id}=    Get From Dictionary    ${m}    id
            ${id_ok}=    Evaluate    isinstance($id, int)
            Run Keyword If    not ${id_ok}    Add Error    Type: payment_methods[${i}].id must be int (got ${id})
        END
        IF    ${ok_type}
            ${type}=    Get From Dictionary    ${m}    type
            ${type_ok}=    Evaluate    isinstance($type, str)
            Run Keyword If    not ${type_ok}    Add Error    Type: payment_methods[${i}].type must be string (got ${type})
        END
        IF    ${ok_title}
            ${title}=    Get From Dictionary    ${m}    title
            ${title_ok}=    Evaluate    isinstance($title, str)
            Run Keyword If    not ${title_ok}    Add Error    Type: payment_methods[${i}].title must be string (got ${title})
        END
        IF    ${ok_click}
            ${click}=    Get From Dictionary    ${m}    is_clickable
            ${click_ok}=    Evaluate    isinstance($click, bool)
            Run Keyword If    not ${click_ok}    Add Error    Type: payment_methods[${i}].is_clickable must be bool (got ${click})
        END

        ${i}=    Evaluate    ${i}+1
    END

Validate Business Rules
    ${has_pm}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${RESPONSE}    payment_methods
    IF    not ${has_pm}
        Add Error    BusinessRules: missing payment_methods
        Return From Keyword
    END

    ${methods}=    Get From Dictionary    ${RESPONSE}    payment_methods
    ${is_list}=    Evaluate    isinstance($methods, list)
    IF    not ${is_list}
        Add Error    BusinessRules: payment_methods must be list
        Return From Keyword
    END

    ${i}=    Set Variable    0
    FOR    ${m}    IN    @{methods}
        ${type}=    Get From Dictionary    ${m}    type
        ${click}=   Get From Dictionary    ${m}    is_clickable

        IF    ${click} == False
            Log    R2: method payment_methods[${i}] not selectable (is_clickable=false)
        END

        ${type_norm}=    Evaluate    str($type).strip().lower()
        IF    '${type_norm}' == 'bnpl'
            Validate BNPL Options Rules    ${m}    ${i}
        END

        ${i}=    Evaluate    ${i}+1
    END

Validate BNPL Options Rules
    [Arguments]    ${m}    ${idx}
    ${click}=    Get From Dictionary    ${m}    is_clickable

    ${has_opt}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    options
    IF    not ${has_opt}
        Add Error    R4: BNPL payment_methods[${idx}] missing 'options'
        Return From Keyword
    END

    ${options}=    Get From Dictionary    ${m}    options
    ${is_list}=    Evaluate    isinstance($options, list)
    IF    not ${is_list}
        Add Error    R4: BNPL payment_methods[${idx}].options must be an array/list
        Return From Keyword
    END

    ${opt_len}=    Get Length    ${options}
    IF    ${click} == True and ${opt_len} == 0
        Add Error    R4: BNPL payment_methods[${idx}] is clickable but options is empty
        Return From Keyword
    END

    @{eligible}=    Create List
    FOR    ${o}    IN    @{options}
        ${sid}=     Get From Dictionary    ${o}    source_id
        ${credit}=  Get From Dictionary    ${o}    credit
        ${active}=  Get From Dictionary    ${o}    is_active
        ${ptype}=   Get From Dictionary    ${o}    price_type

        IF    '${ptype}' != 'CASH_PRICE' and '${ptype}' != 'CREDIT_PRICE'
            Add Error    R7: option source_id=${sid} has invalid price_type='${ptype}'
        END

        ${is_eligible}=    Evaluate    ($active is True) and isinstance($credit, int) and ($credit > 0)
        IF    ${is_eligible}
            Append To List    ${eligible}    ${o}
        ELSE
            Log    R5: Ineligible option source_id=${sid} (active=${active}, credit=${credit})
        END
    END

    ${elig_len}=    Get Length    ${eligible}
    IF    ${elig_len} > 0
        @{defaults}=    Create List
        FOR    ${eo}    IN    @{eligible}
            ${d}=    Get From Dictionary    ${eo}    is_default
            Run Keyword If    ${d} == True    Append To List    ${defaults}    ${eo}
        END
        ${dlen}=    Get Length    ${defaults}
        IF    ${dlen} != 1
            Add Error    R6: expected exactly 1 default among eligible options but found ${dlen} (bnpl index=${idx})
        END
    END
