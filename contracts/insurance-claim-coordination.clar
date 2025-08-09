;; Insurance Claim Coordination Contract
;; Facilitates jewelry repair and replacement for insurance claims

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-CLAIM (err u101))
(define-constant ERR-CLAIM-CLOSED (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-INPUT (err u105))

;; Data Variables
(define-data-var claim-counter uint u0)
(define-data-var service-fee uint u500000) ;; 0.5 STX coordination fee

;; Data Maps
(define-map claims
  { claim-id: uint }
  {
    claimant: principal,
    insurance-company: principal,
    claim-number: (string-ascii 30),
    item-description: (string-ascii 150),
    estimated-value: uint,
    claim-date: uint,
    status: (string-ascii 15),
    assigned-service: (optional principal),
    repair-cost: uint,
    settlement-amount: uint
  }
)

(define-map claim-documents
  { claim-id: uint, document-type: (string-ascii 20) }
  {
    document-hash: (buff 32),
    uploaded-by: principal,
    upload-date: uint
  }
)

(define-map service-providers
  { provider: principal }
  {
    business-name: (string-ascii 50),
    service-types: (list 5 (string-ascii 20)),
    rating: uint,
    claims-handled: uint,
    status: (string-ascii 10)
  }
)

;; Read-only functions
(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-claim-document (claim-id uint) (document-type (string-ascii 20)))
  (map-get? claim-documents { claim-id: claim-id, document-type: document-type })
)

(define-read-only (get-service-provider (provider principal))
  (map-get? service-providers { provider: provider })
)

(define-read-only (get-claim-counter)
  (var-get claim-counter)
)

(define-read-only (get-service-fee)
  (var-get service-fee)
)

;; Private functions
(define-private (is-valid-status (status (string-ascii 15)))
  (or
    (is-eq status "submitted")
    (is-eq status "under-review")
    (is-eq status "approved")
    (is-eq status "in-repair")
    (is-eq status "completed")
    (is-eq status "settled")
    (is-eq status "denied")
  )
)

(define-private (is-valid-service-type (service-type (string-ascii 20)))
  (or
    (is-eq service-type "jewelry-repair")
    (is-eq service-type "watch-repair")
    (is-eq service-type "appraisal")
    (is-eq service-type "replacement")
    (is-eq service-type "restoration")
  )
)

;; Public functions
(define-public (register-claim
  (insurance-company principal)
  (claim-number (string-ascii 30))
  (item-description (string-ascii 150))
  (estimated-value uint))
  (let
    (
      (new-claim-id (+ (var-get claim-counter) u1))
      (fee-required (var-get service-fee))
    )
    (asserts! (> estimated-value u0) ERR-INVALID-INPUT)
    (asserts! (> (len claim-number) u0) ERR-INVALID-INPUT)
    (asserts! (> (len item-description) u0) ERR-INVALID-INPUT)

    (try! (stx-transfer? fee-required tx-sender (as-contract tx-sender)))

    (map-set claims
      { claim-id: new-claim-id }
      {
        claimant: tx-sender,
        insurance-company: insurance-company,
        claim-number: claim-number,
        item-description: item-description,
        estimated-value: estimated-value,
        claim-date: block-height,
        status: "submitted",
        assigned-service: none,
        repair-cost: u0,
        settlement-amount: u0
      }
    )

    (var-set claim-counter new-claim-id)
    (ok new-claim-id)
  )
)

(define-public (register-service-provider
  (business-name (string-ascii 50))
  (service-types (list 5 (string-ascii 20))))
  (begin
    (asserts! (> (len business-name) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? service-providers { provider: tx-sender })) ERR-ALREADY-EXISTS)

    (map-set service-providers
      { provider: tx-sender }
      {
        business-name: business-name,
        service-types: service-types,
        rating: u100,
        claims-handled: u0,
        status: "active"
      }
    )

    (ok true)
  )
)

(define-public (assign-service-provider (claim-id uint) (service-provider principal))
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-INVALID-CLAIM))
      (provider-data (unwrap! (get-service-provider service-provider) ERR-INVALID-INPUT))
    )
    (asserts! (is-eq tx-sender (get insurance-company claim-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status claim-data) "approved") ERR-INVALID-INPUT)
    (asserts! (is-eq (get status provider-data) "active") ERR-INVALID-INPUT)

    (map-set claims
      { claim-id: claim-id }
      (merge claim-data {
        assigned-service: (some service-provider),
        status: "in-repair"
      })
    )

    (ok true)
  )
)

(define-public (update-claim-status (claim-id uint) (new-status (string-ascii 15)))
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-INVALID-CLAIM))
    )
    (asserts! (is-valid-status new-status) ERR-INVALID-INPUT)
    (asserts!
      (or
        (is-eq tx-sender (get insurance-company claim-data))
        (is-eq (some tx-sender) (get assigned-service claim-data))
      )
      ERR-NOT-AUTHORIZED
    )

    (map-set claims
      { claim-id: claim-id }
      (merge claim-data { status: new-status })
    )

    (ok true)
  )
)

(define-public (submit-repair-cost (claim-id uint) (repair-cost uint))
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-INVALID-CLAIM))
    )
    (asserts! (is-eq (some tx-sender) (get assigned-service claim-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status claim-data) "in-repair") ERR-INVALID-INPUT)
    (asserts! (> repair-cost u0) ERR-INVALID-INPUT)

    (map-set claims
      { claim-id: claim-id }
      (merge claim-data { repair-cost: repair-cost })
    )

    (ok true)
  )
)

(define-public (settle-claim (claim-id uint) (settlement-amount uint))
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-INVALID-CLAIM))
      (provider-data (unwrap! (get-service-provider (unwrap! (get assigned-service claim-data) ERR-INVALID-INPUT)) ERR-INVALID-INPUT))
    )
    (asserts! (is-eq tx-sender (get insurance-company claim-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status claim-data) "completed") ERR-INVALID-INPUT)
    (asserts! (> settlement-amount u0) ERR-INVALID-INPUT)

    (map-set claims
      { claim-id: claim-id }
      (merge claim-data {
        settlement-amount: settlement-amount,
        status: "settled"
      })
    )

    (map-set service-providers
      { provider: (unwrap! (get assigned-service claim-data) ERR-INVALID-INPUT) }
      (merge provider-data {
        claims-handled: (+ (get claims-handled provider-data) u1)
      })
    )

    (ok true)
  )
)

(define-public (upload-document (claim-id uint) (document-type (string-ascii 20)) (document-hash (buff 32)))
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-INVALID-CLAIM))
    )
    (asserts!
      (or
        (is-eq tx-sender (get claimant claim-data))
        (is-eq tx-sender (get insurance-company claim-data))
        (is-eq (some tx-sender) (get assigned-service claim-data))
      )
      ERR-NOT-AUTHORIZED
    )

    (map-set claim-documents
      { claim-id: claim-id, document-type: document-type }
      {
        document-hash: document-hash,
        uploaded-by: tx-sender,
        upload-date: block-height
      }
    )

    (ok true)
  )
)

(define-public (rate-service-provider (provider principal) (rating uint))
  (let
    (
      (provider-data (unwrap! (get-service-provider provider) ERR-INVALID-INPUT))
    )
    (asserts! (<= rating u100) ERR-INVALID-INPUT)
    (asserts! (>= rating u1) ERR-INVALID-INPUT)

    (map-set service-providers
      { provider: provider }
      (merge provider-data { rating: rating })
    )

    (ok true)
  )
)

(define-public (update-service-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)
    (var-set service-fee new-fee)
    (ok true)
  )
)
