*** Settings ***
Library    JSONLibrary
Library    Collections
Library    OperatingSystem

*** Keywords ***
Load Payment Response
    [Arguments]    ${file}
    ${path}=    Join Path    ${CURDIR}    ..    testdata    ${file}
    ${json}=    Load JSON From File    ${path}
    Set Suite Variable    ${RESPONSE}    ${json}
    ${err}=    Create List
    Set Suite Variable    ${ERRORS}    ${err}

Add Error
    [Arguments]    ${msg}
    Append To List    ${ERRORS}    ${msg}

Assert Validation Passed
    ${n}=    Get Length    ${ERRORS}
    Run Keyword If    ${n} > 0    Fail    Validation failed: @{ERRORS}

Assert Validation Failed
    ${n}=    Get Length    ${ERRORS}
    Run Keyword If    ${n} == 0    Fail    Expected fail but passed

Validate Transport Status
    ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${RESPONSE}    status
    Run Keyword If    not ${ok}    Add Error    missing status
    Return From Keyword If    not ${ok}
    ${s}=    Get From Dictionary    ${RESPONSE}    status
    Run Keyword If    ${s} != 200    Add Error    status not 200

Validate Schema
    ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${RESPONSE}    payment_methods
    Run Keyword If    not ${ok}    Add Error    missing payment_methods
    Return From Keyword If    not ${ok}
    ${methods}=    Get From Dictionary    ${RESPONSE}    payment_methods
    ${is_list}=    Evaluate    isinstance($methods, list)
    Run Keyword If    not ${is_list}    Add Error    payment_methods not list
    ${i}=    Set Variable    0
    FOR    ${m}    IN    @{methods}
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    id
        Run Keyword If    not ${ok}    Add Error    [${i}] no id
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    type
        Run Keyword If    not ${ok}    Add Error    [${i}] no type
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    title
        Run Keyword If    not ${ok}    Add Error    [${i}] no title
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    is_clickable
        Run Keyword If    not ${ok}    Add Error    [${i}] no is_clickable
        ${id_ok}=    Evaluate    isinstance($m.get('id'), int) if 'id' in $m else True
        Run Keyword If    not ${id_ok}    Add Error    [${i}] id must be int
        ${type_ok}=    Evaluate    isinstance($m.get('type'), str) if 'type' in $m else True
        Run Keyword If    not ${type_ok}    Add Error    [${i}] type must be str
        ${title_ok}=    Evaluate    isinstance($m.get('title'), str) if 'title' in $m else True
        Run Keyword If    not ${title_ok}    Add Error    [${i}] title must be str
        ${click_ok}=    Evaluate    isinstance($m.get('is_clickable'), bool) if 'is_clickable' in $m else True
        Run Keyword If    not ${click_ok}    Add Error    [${i}] is_clickable must be bool
        ${i}=    Evaluate    ${i}+1
    END
    ${ids}=    Evaluate    [m.get('id') for m in $methods if 'id' in m]
    ${dup}=    Evaluate    len($ids) != len(set($ids))
    Run Keyword If    ${dup}    Add Error    duplicate payment_method id

Validate Business Rules
    ${methods}=    Get From Dictionary    ${RESPONSE}    payment_methods
    ${idx}=    Set Variable    0
    FOR    ${m}    IN    @{methods}
        ${t}=    Get From Dictionary    ${m}    type
        ${t}=    Evaluate    str($t).lower()
        Run Keyword If    '${t}' == 'bnpl'    Validate BNPL    ${m}    ${idx}
        ${idx}=    Evaluate    ${idx}+1
    END

Validate and collect eligible option
    [Arguments]    ${o}    ${idx}    ${eligible}
    ${has}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    price_type
    Run Keyword If    not ${has}    Return From Keyword
    ${has}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    credit
    Run Keyword If    not ${has}    Return From Keyword
    ${has}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    is_active
    Run Keyword If    not ${has}    Return From Keyword
    ${pt}=    Get From Dictionary    ${o}    price_type
    Run Keyword If    '${pt}' != 'CASH_PRICE' and '${pt}' != 'CREDIT_PRICE'    Add Error    bad price_type ${pt}
    ${credit}=    Get From Dictionary    ${o}    credit
    ${credit_ok}=    Evaluate    isinstance($credit, int) and $credit >= 0
    Run Keyword If    not ${credit_ok}    Add Error    BNPL[${idx}] option credit must be int >= 0
    ${active}=    Get From Dictionary    ${o}    is_active
    ${ok}=    Evaluate    $active and isinstance($credit, int) and $credit > 0
    Run Keyword If    ${ok}    Append To List    ${eligible}    ${o}

Validate BNPL
    [Arguments]    ${m}    ${idx}
    ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${m}    options
    Run Keyword If    not ${ok}    Add Error    BNPL[${idx}] no options
    Return From Keyword If    not ${ok}
    ${opts}=    Get From Dictionary    ${m}    options
    ${click}=    Get From Dictionary    ${m}    is_clickable
    ${opt_len}=    Get Length    ${opts}
    Run Keyword If    ${click} and ${opt_len} == 0    Add Error    BNPL[${idx}] options empty
    ${eligible}=    Create List
    ${oi}=    Set Variable    0
    FOR    ${o}    IN    @{opts}
        ${option_ok}=    Set Variable    ${TRUE}
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    source_id
        Run Keyword If    not ${ok}    Add Error    BNPL[${idx}] option[${oi}] missing source_id
        Run Keyword If    not ${ok}    Set Variable    ${option_ok}    ${FALSE}
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    title
        Run Keyword If    not ${ok}    Add Error    BNPL[${idx}] option[${oi}] missing title
        Run Keyword If    not ${ok}    Set Variable    ${option_ok}    ${FALSE}
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    credit
        Run Keyword If    not ${ok}    Add Error    BNPL[${idx}] option[${oi}] missing credit
        Run Keyword If    not ${ok}    Set Variable    ${option_ok}    ${FALSE}
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    is_active
        Run Keyword If    not ${ok}    Add Error    BNPL[${idx}] option[${oi}] missing is_active
        Run Keyword If    not ${ok}    Set Variable    ${option_ok}    ${FALSE}
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    is_default
        Run Keyword If    not ${ok}    Add Error    BNPL[${idx}] option[${oi}] missing is_default
        Run Keyword If    not ${ok}    Set Variable    ${option_ok}    ${FALSE}
        ${ok}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${o}    price_type
        Run Keyword If    not ${ok}    Add Error    BNPL[${idx}] option[${oi}] missing price_type
        Run Keyword If    not ${ok}    Set Variable    ${option_ok}    ${FALSE}
        Run Keyword If    ${option_ok}    Validate and collect eligible option    ${o}    ${idx}    ${eligible}
        ${oi}=    Evaluate    ${oi}+1
    END
    ${defaults}=    Create List
    FOR    ${e}    IN    @{eligible}
        ${d}=    Get From Dictionary    ${e}    is_default
        Run Keyword If    ${d}    Append To List    ${defaults}    ${e}
    END
    ${n}=    Get Length    ${defaults}
    ${elen}=    Get Length    ${eligible}
    Run Keyword If    ${elen} > 0 and ${n} != 1    Add Error    BNPL[${idx}] need 1 default got ${n}
