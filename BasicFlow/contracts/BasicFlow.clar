;;; ===================================================
;;; BASICFLOW - UNIVERSAL BASIC INCOME DISTRIBUTION
;;; ===================================================
;;; A blockchain-based UBI system for transparent, automated
;;; distribution of basic income to verified community members.
;;; Addresses UN SDG 1: No Poverty through direct wealth redistribution.
;;; ===================================================

;; ===================================================
;; CONSTANTS AND ERROR CODES
;; ===================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-AMOUNT (err u401))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-RECIPIENT-NOT-FOUND (err u403))
(define-constant ERR-ALREADY-CLAIMED (err u404))
(define-constant ERR-NOT-ELIGIBLE (err u405))
(define-constant ERR-VERIFICATION-PENDING (err u406))
(define-constant ERR-INVALID-PERIOD (err u407))
(define-constant ERR-PROGRAM-INACTIVE (err u408))
(define-constant ERR-DUPLICATE-REGISTRATION (err u409))
(define-constant ERR-INVALID-VERIFIER (err u410))

;; UBI Distribution Periods (in blocks)
(define-constant MONTHLY-PERIOD u4320) ;; ~30 days
(define-constant WEEKLY-PERIOD u1008)  ;; ~7 days
(define-constant DAILY-PERIOD u144)    ;; ~1 day

;; Verification Levels
(define-constant LEVEL-UNVERIFIED u0)
(define-constant LEVEL-BASIC u1)
(define-constant LEVEL-VERIFIED u2)
(define-constant LEVEL-PREMIUM u3)

;; Minimum stake requirements
(define-constant MIN-VERIFIER-STAKE u50000000) ;; 50 STX
(define-constant MIN-FUND-CONTRIBUTION u1000000) ;; 1 STX

;; ===================================================
;; DATA STRUCTURES
;; ===================================================

;; UBI Recipients Registry
(define-map ubi-recipients
    { recipient: principal }
    {
        verification-level: uint,
        registration-date: uint,
        last-claim-period: uint,
        total-claimed: uint,
        is-active: bool,
        kyc-hash: (buff 32),
        location-region: (string-ascii 50),
        dependency-score: uint, ;; 0-100, higher = more dependent on UBI
        verified-by: (optional principal),
        verification-date: (optional uint)
    }
)

;; UBI Program Configuration
(define-map ubi-programs
    { program-id: uint }
    {
        program-name: (string-ascii 100),
        monthly-amount: uint, ;; STX amount per month
        target-region: (string-ascii 50),
        eligibility-criteria: (string-ascii 200),
        total-budget: uint,
        distributed-amount: uint,
        start-block: uint,
        end-block: uint,
        is-active: bool,
        created-by: principal,
        recipient-count: uint,
        verification-required: uint ;; minimum verification level
    }
)

;; Distribution Claims History
(define-map distribution-claims
    { claim-id: uint }
    {
        recipient: principal,
        program-id: uint,
        amount-claimed: uint,
        claim-period: uint,
        claim-date: uint,
        distribution-type: (string-ascii 20), ;; "MONTHLY", "WEEKLY", "EMERGENCY"
        verification-status: bool,
        claim-hash: (buff 32)
    }
)

;; Community Verifiers
(define-map community-verifiers
    { verifier: principal }
    {
        stake-amount: uint,
        verifications-completed: uint,
        accuracy-score: uint, ;; 0-100
        is-active: bool,
        registration-date: uint,
        region-focus: (string-ascii 50),
        reputation-score: uint
    }
)

;; Funding Sources
(define-map funding-sources
    { funder: principal }
    {
        total-contributed: uint,
        contributions-count: uint,
        preferred-programs: (list 5 uint),
        is-recurring: bool,
        last-contribution: uint,
        contribution-frequency: uint
    }
)

;; Emergency Distributions
(define-map emergency-distributions
    { emergency-id: uint }
    {
        triggered-by: principal,
        target-region: (string-ascii 50),
        emergency-type: (string-ascii 100),
        amount-per-recipient: uint,
        total-recipients: uint,
        total-distributed: uint,
        trigger-date: uint,
        is-active: bool,
        approval-votes: uint,
        required-votes: uint
    }
)

;; ===================================================
;; DATA VARIABLES
;; ===================================================

(define-data-var next-program-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var next-emergency-id uint u1)
(define-data-var total-recipients uint u0)
(define-data-var total-distributed uint u0)
(define-data-var platform-fee-rate uint u50) ;; 0.5%
(define-data-var current-distribution-period uint u0)

;; ===================================================
;; PRIVATE FUNCTIONS
;; ===================================================

;; Calculate current distribution period
(define-private (get-current-period (frequency uint))
    (/ stacks-block-height frequency)
)

;; Validate verification level
(define-private (is-valid-verification-level (level uint))
    (or (is-eq level LEVEL-UNVERIFIED)
        (or (is-eq level LEVEL-BASIC)
            (or (is-eq level LEVEL-VERIFIED)
                (is-eq level LEVEL-PREMIUM))))
)

;; Calculate UBI amount based on dependency score
(define-private (calculate-ubi-amount (base-amount uint) (dependency-score uint))
    (let (
        (multiplier (+ u100 dependency-score)) ;; 100-200%
    )
        (/ (* base-amount multiplier) u100)
    )
)

;; Check if recipient is eligible for program
(define-private (is-eligible-for-program (recipient principal) (program-id uint))
    (match (map-get? ubi-recipients { recipient: recipient })
        recipient-data
            (match (map-get? ubi-programs { program-id: program-id })
                program-data
                    (and (get is-active recipient-data)
                         (get is-active program-data)
                         (>= (get verification-level recipient-data) 
                             (get verification-required program-data)))
                false)
        false)
)

;; Generate unique claim hash
(define-private (generate-claim-hash (recipient principal) (amount uint) (period uint))
    (keccak256 (concat (concat (unwrap-panic (to-consensus-buff? recipient))
                               (unwrap-panic (to-consensus-buff? amount)))
                       (unwrap-panic (to-consensus-buff? period))))
)

;; ===================================================
;; PUBLIC FUNCTIONS - RECIPIENT MANAGEMENT
;; ===================================================

;; Register as UBI recipient
(define-public (register-recipient
    (kyc-hash (buff 32))
    (location-region (string-ascii 50))
    (dependency-score uint))
    
    (let (
        (registration-date stacks-block-height)
    )
    
    (asserts! (is-none (map-get? ubi-recipients { recipient: tx-sender })) ERR-DUPLICATE-REGISTRATION)
    (asserts! (<= dependency-score u100) ERR-INVALID-AMOUNT)
    
    ;; Register recipient
    (map-set ubi-recipients
        { recipient: tx-sender }
        {
            verification-level: LEVEL-UNVERIFIED,
            registration-date: registration-date,
            last-claim-period: u0,
            total-claimed: u0,
            is-active: true,
            kyc-hash: kyc-hash,
            location-region: location-region,
            dependency-score: dependency-score,
            verified-by: none,
            verification-date: none
        }
    )
    
    (var-set total-recipients (+ (var-get total-recipients) u1))
    (ok true)
    )
)

;; Verify recipient (by community verifier)
(define-public (verify-recipient (recipient principal) (verification-level uint))
    (let (
        (verifier-data (unwrap! (map-get? community-verifiers { verifier: tx-sender }) ERR-INVALID-VERIFIER))
        (recipient-data (unwrap! (map-get? ubi-recipients { recipient: recipient }) ERR-RECIPIENT-NOT-FOUND))
    )
    
    (asserts! (get is-active verifier-data) ERR-INVALID-VERIFIER)
    (asserts! (is-valid-verification-level verification-level) ERR-INVALID-AMOUNT)
    (asserts! (> verification-level (get verification-level recipient-data)) ERR-INVALID-AMOUNT)
    
    ;; Update recipient verification
    (map-set ubi-recipients
        { recipient: recipient }
        (merge recipient-data {
            verification-level: verification-level,
            verified-by: (some tx-sender),
            verification-date: (some stacks-block-height)
        })
    )
    
    ;; Update verifier stats
    (map-set community-verifiers
        { verifier: tx-sender }
        (merge verifier-data {
            verifications-completed: (+ (get verifications-completed verifier-data) u1)
        })
    )
    
    (ok true)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - PROGRAM MANAGEMENT
;; ===================================================

;; Create UBI program
(define-public (create-ubi-program
    (program-name (string-ascii 100))
    (monthly-amount uint)
    (target-region (string-ascii 50))
    (eligibility-criteria (string-ascii 200))
    (total-budget uint)
    (duration-months uint)
    (verification-required uint))
    
    (let (
        (program-id (var-get next-program-id))
        (start-block stacks-block-height)
        (end-block (+ start-block (* duration-months MONTHLY-PERIOD)))
    )
    
    (asserts! (> monthly-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> total-budget u0) ERR-INVALID-AMOUNT)
    (asserts! (> duration-months u0) ERR-INVALID-AMOUNT)
    (asserts! (is-valid-verification-level verification-required) ERR-INVALID-AMOUNT)
    
    ;; Transfer budget to contract
    (try! (stx-transfer? total-budget tx-sender (as-contract tx-sender)))
    
    ;; Create program
    (map-set ubi-programs
        { program-id: program-id }
        {
            program-name: program-name,
            monthly-amount: monthly-amount,
            target-region: target-region,
            eligibility-criteria: eligibility-criteria,
            total-budget: total-budget,
            distributed-amount: u0,
            start-block: start-block,
            end-block: end-block,
            is-active: true,
            created-by: tx-sender,
            recipient-count: u0,
            verification-required: verification-required
        }
    )
    
    (var-set next-program-id (+ program-id u1))
    (ok program-id)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - DISTRIBUTION CLAIMS
;; ===================================================

;; Claim monthly UBI distribution
(define-public (claim-ubi (program-id uint))
    (let (
        (program (unwrap! (map-get? ubi-programs { program-id: program-id }) ERR-INVALID-PERIOD))
        (recipient-data (unwrap! (map-get? ubi-recipients { recipient: tx-sender }) ERR-RECIPIENT-NOT-FOUND))
        (current-period (get-current-period MONTHLY-PERIOD))
        (base-amount (get monthly-amount program))
        (final-amount (calculate-ubi-amount base-amount (get dependency-score recipient-data)))
        (claim-id (var-get next-claim-id))
        (claim-hash (generate-claim-hash tx-sender final-amount current-period))
    )
    
    (asserts! (is-eligible-for-program tx-sender program-id) ERR-NOT-ELIGIBLE)
    (asserts! (get is-active program) ERR-PROGRAM-INACTIVE)
    (asserts! (> current-period (get last-claim-period recipient-data)) ERR-ALREADY-CLAIMED)
    (asserts! (>= (- (get total-budget program) (get distributed-amount program)) final-amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (>= stacks-block-height (get start-block program)) ERR-INVALID-PERIOD)
    (asserts! (< stacks-block-height (get end-block program)) ERR-INVALID-PERIOD)
    
    ;; Transfer UBI amount to recipient
    (try! (as-contract (stx-transfer? final-amount tx-sender tx-sender)))
    
    ;; Record claim
    (map-set distribution-claims
        { claim-id: claim-id }
        {
            recipient: tx-sender,
            program-id: program-id,
            amount-claimed: final-amount,
            claim-period: current-period,
            claim-date: stacks-block-height,
            distribution-type: "MONTHLY",
            verification-status: true,
            claim-hash: claim-hash
        }
    )
    
    ;; Update recipient data
    (map-set ubi-recipients
        { recipient: tx-sender }
        (merge recipient-data {
            last-claim-period: current-period,
            total-claimed: (+ (get total-claimed recipient-data) final-amount)
        })
    )
    
    ;; Update program stats
    (map-set ubi-programs
        { program-id: program-id }
        (merge program {
            distributed-amount: (+ (get distributed-amount program) final-amount)
        })
    )
    
    (var-set next-claim-id (+ claim-id u1))
    (var-set total-distributed (+ (var-get total-distributed) final-amount))
    
    (ok final-amount)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - VERIFIER MANAGEMENT
;; ===================================================

;; Register as community verifier
(define-public (register-verifier (region-focus (string-ascii 50)))
    (let (
        (stake-amount MIN-VERIFIER-STAKE)
    )
    
    (asserts! (is-none (map-get? community-verifiers { verifier: tx-sender })) ERR-DUPLICATE-REGISTRATION)
    
    ;; Transfer stake
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Register verifier
    (map-set community-verifiers
        { verifier: tx-sender }
        {
            stake-amount: stake-amount,
            verifications-completed: u0,
            accuracy-score: u100,
            is-active: true,
            registration-date: stacks-block-height,
            region-focus: region-focus,
            reputation-score: u100
        }
    )
    
    (ok true)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - FUNDING
;; ===================================================

;; Contribute to UBI fund
(define-public (contribute-to-fund (amount uint) (target-programs (list 5 uint)))
    (let (
        (existing-funder (map-get? funding-sources { funder: tx-sender }))
    )
    
    (asserts! (>= amount MIN-FUND-CONTRIBUTION) ERR-INVALID-AMOUNT)
    
    ;; Transfer contribution to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update or create funder record
    (match existing-funder
        funder-data
        (map-set funding-sources
            { funder: tx-sender }
            (merge funder-data {
                total-contributed: (+ (get total-contributed funder-data) amount),
                contributions-count: (+ (get contributions-count funder-data) u1),
                preferred-programs: target-programs,
                last-contribution: stacks-block-height
            })
        )
        (map-set funding-sources
            { funder: tx-sender }
            {
                total-contributed: amount,
                contributions-count: u1,
                preferred-programs: target-programs,
                is-recurring: false,
                last-contribution: stacks-block-height,
                contribution-frequency: u0
            }
        )
    )
    
    (ok true)
    )
)

;; ===================================================
;; READ-ONLY FUNCTIONS
;; ===================================================

;; Get recipient information
(define-read-only (get-recipient-info (recipient principal))
    (map-get? ubi-recipients { recipient: recipient })
)

;; Get program information
(define-read-only (get-program-info (program-id uint))
    (map-get? ubi-programs { program-id: program-id })
)

;; Get claim information
(define-read-only (get-claim-info (claim-id uint))
    (map-get? distribution-claims { claim-id: claim-id })
)

;; Check if recipient can claim
(define-read-only (can-claim-ubi (recipient principal) (program-id uint))
    (match (map-get? ubi-recipients { recipient: recipient })
        recipient-data
            (let (
                (current-period (get-current-period MONTHLY-PERIOD))
            )
                (and (is-eligible-for-program recipient program-id)
                     (> current-period (get last-claim-period recipient-data)))
            )
        false
    )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-recipients: (var-get total-recipients),
        total-programs: (var-get next-program-id),
        total-distributed: (var-get total-distributed),
        total-claims: (var-get next-claim-id),
        current-period: (get-current-period MONTHLY-PERIOD)
    }
)

;; Calculate claimable amount for recipient
(define-read-only (calculate-claimable-amount (recipient principal) (program-id uint))
    (match (map-get? ubi-recipients { recipient: recipient })
        recipient-data
            (match (map-get? ubi-programs { program-id: program-id })
                program-data
                    (if (is-eligible-for-program recipient program-id)
                        (calculate-ubi-amount 
                            (get monthly-amount program-data)
                            (get dependency-score recipient-data))
                        u0)
                u0)
        u0)
)

;; ===================================================
;; ADMIN FUNCTIONS
;; ===================================================

;; Emergency pause program
(define-public (pause-program (program-id uint))
    (let (
        (program (unwrap! (map-get? ubi-programs { program-id: program-id }) ERR-INVALID-PERIOD))
    )
    
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (is-eq tx-sender (get created-by program))) ERR-NOT-AUTHORIZED)
    
    (map-set ubi-programs
        { program-id: program-id }
        (merge program { is-active: false })
    )
    
    (ok true)
    )
)