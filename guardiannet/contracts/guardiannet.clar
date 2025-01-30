;; GuardianNet: Decentralized Insurance Collective
;; SPDX-License-Identifier: MIT

;; Error Constants
(define-constant err-unauthorized (err u300))
(define-constant err-already-member (err u100))
(define-constant err-low-deposit (err u101))
(define-constant err-payout-exceeded (err u103))
(define-constant err-verification-failed (err u201))
(define-constant err-invalid-incident-type (err u202))
(define-constant err-invalid-impact-level (err u203))
(define-constant err-missing-proof (err u204))
(define-constant err-invalid-incident-id (err u205))

;; Contract Constants
(define-constant admin tx-sender)
(define-constant entry-deposit u10000000) ;; 0.1 STX
(define-constant ballot-duration u604800) ;; 7 days in seconds
(define-constant consensus-threshold u66) ;; 66% approval required

;; Incident Type Definitions
(define-map incident-rules
  {incident-type: (string-ascii 50)}
  {
    impact-floor: uint,
    impact-ceiling: uint,
    required-proof: (list 3 (string-ascii 50))
  }
)

;; Validator Trait Definition
(define-trait validator-trait
  (
    (verify-incident 
      (
        (string-ascii 50)  ;; incident type
        (list 10 (string-ascii 100))  ;; incident proof
      ) 
      (response 
        {
          valid: bool, 
          impact-score: uint
        } 
        uint
      )
    )
  )
)

;; Participant Tracking
(define-map participants 
  {user: principal}
  {
    deposit-amount: uint,
    join-block: uint,
    status-active: bool
  }
)

;; Incident Status Enum
(define-constant status-pending u0)
(define-constant status-verified u1)
(define-constant status-approved u2)
(define-constant status-denied u3)

;; Incident Tracking
(define-map incidents 
  {incident-id: uint}
  {
    reporter: principal,
    payout: uint,
    incident-type: (string-ascii 50),
    status: uint,
    impact-score: uint,
    ballot-end: uint,
    approve-count: uint,
    reject-count: uint,
    incident-proof: (list 10 (string-ascii 100))
  }
)

;; Global State Variables
(define-data-var pool-balance uint u0)
(define-data-var participant-count uint u0)
(define-data-var incident-count uint u0)

;; Participant Registration
(define-public (join-network)
  (let 
    (
      (deposit (stx-get-balance tx-sender))
    )
    ;; Check if already registered
    (asserts! (is-none (map-get? participants {user: tx-sender})) err-already-member)
    
    ;; Validate deposit amount
    (asserts! (>= deposit entry-deposit) err-low-deposit)
    
    ;; Transfer deposit to contract
    (try! (stx-transfer? deposit tx-sender (as-contract tx-sender)))
    
    ;; Record participant
    (map-set participants 
      {user: tx-sender}
      {
        deposit-amount: deposit,
        join-block: block-height,
        status-active: true
      }
    )
    
    ;; Update network stats
    (var-set pool-balance (+ (var-get pool-balance) deposit))
    (var-set participant-count (+ (var-get participant-count) u1))
    
    (ok true)
  )
)

;; Add Incident Rules (Admin Function)
(define-public (set-incident-rules 
  (incident-type (string-ascii 50))
  (impact-floor uint)
  (impact-ceiling uint)
  (required-proof (list 3 (string-ascii 50)))
)
  (begin
    (asserts! (is-eq tx-sender admin) err-unauthorized)
    (asserts! (> (len incident-type) u0) err-invalid-incident-type)
    (asserts! (<= impact-floor impact-ceiling) err-invalid-impact-level)
    (asserts! (is-eq (len required-proof) u3) err-missing-proof)
    
    (map-set incident-rules 
      {incident-type: incident-type}
      {
        impact-floor: impact-floor,
        impact-ceiling: impact-ceiling,
        required-proof: required-proof
      }
    )
    
    (ok true)
  )
)

;; Report Incident with Validator
(define-public (report-incident 
  (payout-amount uint)
  (incident-type (string-ascii 50))
  (incident-proof (list 10 (string-ascii 100)))
  (validator-contract <validator-trait>)
)
  (let 
    (
      ;; Check participant status
      (participant (unwrap! (map-get? participants {user: tx-sender}) err-already-member))
      
      ;; Get incident rules
      (rules (unwrap! 
        (map-get? incident-rules {incident-type: incident-type}) 
        err-unauthorized
      ))
      
      ;; Validate incident
      (validation-result (unwrap! 
        (contract-call? validator-contract verify-incident 
          incident-type 
          incident-proof
        )
        err-verification-failed
      ))
      
      ;; Get current incident ID
      (current-incident-id (var-get incident-count))
    )
    ;; Validate verification result
    (asserts! 
      (and
        (get valid validation-result)
        (>= (get impact-score validation-result) (get impact-floor rules))
        (<= (get impact-score validation-result) (get impact-ceiling rules))
      )
      err-verification-failed
    )
    
    ;; Check payout limit
    (asserts! (<= payout-amount (/ (var-get pool-balance) u2)) err-payout-exceeded)
    
    ;; Record incident
    (map-set incidents 
      {incident-id: current-incident-id}
      {
        reporter: tx-sender,
        payout: payout-amount,
        incident-type: incident-type,
        status: status-verified,
        impact-score: (get impact-score validation-result),
        ballot-end: (+ block-height ballot-duration),
        approve-count: u0,
        reject-count: u0,
        incident-proof: incident-proof
      }
    )
    
    ;; Update counter
    (var-set incident-count (+ current-incident-id u1))
    
    (ok current-incident-id)
  )
)

;; Cast Vote on Incident
(define-public (cast-vote (incident-id uint) (approve bool))
  (let 
    (
      (participant (unwrap! (map-get? participants {user: tx-sender}) err-already-member))
      (current-incident (unwrap! (map-get? incidents {incident-id: incident-id}) err-invalid-incident-id))
    )
    ;; Verify voting window
    (asserts! (< block-height (get ballot-end current-incident)) err-unauthorized)
    
    ;; Record vote
    (if approve 
      (map-set incidents 
        {incident-id: incident-id}
        (merge current-incident {approve-count: (+ (get approve-count current-incident) u1)})
      )
      (map-set incidents 
        {incident-id: incident-id}
        (merge current-incident {reject-count: (+ (get reject-count current-incident) u1)})
      )
    )
    
    ;; Process vote outcome
    (try! (process-votes incident-id))
    
    (ok true)
  )
)

;; Internal Vote Processing
(define-private (process-votes (incident-id uint))
  (let 
    (
      (current-incident (unwrap! (map-get? incidents {incident-id: incident-id}) err-invalid-incident-id))
      (total-votes (+ (get approve-count current-incident) (get reject-count current-incident)))
      (approval-rate 
        (if (> total-votes u0)
            (/ (* (get approve-count current-incident) u100) total-votes)
            u0
        )
      )
    )
    ;; Check consensus threshold
    (if (>= approval-rate consensus-threshold)
      (begin
        ;; Mark approved and process payout
        (map-set incidents 
          {incident-id: incident-id}
          (merge current-incident {status: status-approved})
        )
        (try! (as-contract (stx-transfer? 
          (get payout current-incident) 
          tx-sender 
          (get reporter current-incident)
        )))
        (ok true)
      )
      ;; Mark denied if threshold not met
      (begin
        (map-set incidents 
          {incident-id: incident-id}
          (merge current-incident {status: status-denied})
        )
        (ok false)
      )
    )
  )
)

;; Read-only Network Stats
(define-read-only (get-pool-balance)
  (var-get pool-balance)
)

(define-read-only (get-participant-info (user principal))
  (map-get? participants {user: user})
)

(define-read-only (get-incident-info (incident-id uint))
  (map-get? incidents {incident-id: incident-id})
)

(define-read-only (get-incident-rules (incident-type (string-ascii 50)))
  (map-get? incident-rules {incident-type: incident-type})
)