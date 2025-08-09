;; Appraisal Services Oversight Contract
;; Manages licenses for jewelry appraisers and gemologists

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-LICENSE (err u101))
(define-constant ERR-EXPIRED (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-INPUT (err u105))

;; Data Variables
(define-data-var license-counter uint u0)
(define-data-var appraisal-counter uint u0)
(define-data-var base-fee uint u1500000) ;; 1.5 STX in microSTX

;; Data Maps
(define-map licenses
  { license-id: uint }
  {
    holder: principal,
    appraiser-name: (string-ascii 50),
    license-type: (string-ascii 25),
    certifications: (list 3 (string-ascii 20)),
    issue-date: uint,
    expiration-date: uint,
    status: (string-ascii 10),
    fee-paid: uint,
    appraisals-completed: uint
  }
)

(define-map holder-licenses
  { holder: principal }
  { license-id: uint }
)

(define-map appraisals
  { appraisal-id: uint }
  {
    appraiser-license: uint,
    item-description: (string-ascii 100),
    appraised-value: uint,
    appraisal-date: uint,
    client: principal,
    status: (string-ascii 15)
  }
)

;; Read-only functions
(define-read-only (get-license (license-id uint))
  (map-get? licenses { license-id: license-id })
)

(define-read-only (get-holder-license (holder principal))
  (match (map-get? holder-licenses { holder: holder })
    license-data (get-license (get license-id license-data))
    none
  )
)

(define-read-only (get-appraisal (appraisal-id uint))
  (map-get? appraisals { appraisal-id: appraisal-id })
)

(define-read-only (is-license-valid (license-id uint))
  (match (get-license license-id)
    license-data
      (and
        (is-eq (get status license-data) "active")
        (> (get expiration-date license-data) block-height)
      )
    false
  )
)

(define-read-only (get-license-counter)
  (var-get license-counter)
)

(define-read-only (get-appraisal-counter)
  (var-get appraisal-counter)
)

(define-read-only (get-base-fee)
  (var-get base-fee)
)

;; Private functions
(define-private (is-valid-license-type (license-type (string-ascii 25)))
  (or
    (is-eq license-type "certified-appraiser")
    (is-eq license-type "gemologist")
    (is-eq license-type "insurance-appraiser")
    (is-eq license-type "estate-appraiser")
  )
)

(define-private (is-valid-certification (certification (string-ascii 20)))
  (or
    (is-eq certification "GIA")
    (is-eq certification "AGS")
    (is-eq certification "SSEF")
    (is-eq certification "ASA")
    (is-eq certification "AAA")
  )
)

;; Public functions
(define-public (issue-license
  (holder principal)
  (appraiser-name (string-ascii 50))
  (license-type (string-ascii 25))
  (certifications (list 3 (string-ascii 20)))
  (duration-days uint))
  (let
    (
      (new-license-id (+ (var-get license-counter) u1))
      (fee-required (var-get base-fee))
      (expiration-date (+ block-height (* duration-days u144)))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-license-type license-type) ERR-INVALID-INPUT)
    (asserts! (> duration-days u0) ERR-INVALID-INPUT)
    (asserts! (< duration-days u1095) ERR-INVALID-INPUT)
    (asserts! (> (len appraiser-name) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? holder-licenses { holder: holder })) ERR-ALREADY-EXISTS)

    (try! (stx-transfer? fee-required tx-sender (as-contract tx-sender)))

    (map-set licenses
      { license-id: new-license-id }
      {
        holder: holder,
        appraiser-name: appraiser-name,
        license-type: license-type,
        certifications: certifications,
        issue-date: block-height,
        expiration-date: expiration-date,
        status: "active",
        fee-paid: fee-required,
        appraisals-completed: u0
      }
    )

    (map-set holder-licenses
      { holder: holder }
      { license-id: new-license-id }
    )

    (var-set license-counter new-license-id)
    (ok new-license-id)
  )
)

(define-public (submit-appraisal
  (item-description (string-ascii 100))
  (appraised-value uint)
  (client principal))
  (let
    (
      (license-data (unwrap! (get-holder-license tx-sender) ERR-INVALID-LICENSE))
      (license-id (unwrap! (map-get? holder-licenses { holder: tx-sender }) ERR-INVALID-LICENSE))
      (new-appraisal-id (+ (var-get appraisal-counter) u1))
    )
    (asserts! (is-license-valid (get license-id license-id)) ERR-EXPIRED)
    (asserts! (> appraised-value u0) ERR-INVALID-INPUT)
    (asserts! (> (len item-description) u0) ERR-INVALID-INPUT)

    (map-set appraisals
      { appraisal-id: new-appraisal-id }
      {
        appraiser-license: (get license-id license-id),
        item-description: item-description,
        appraised-value: appraised-value,
        appraisal-date: block-height,
        client: client,
        status: "completed"
      }
    )

    (map-set licenses
      { license-id: (get license-id license-id) }
      (merge license-data {
        appraisals-completed: (+ (get appraisals-completed license-data) u1)
      })
    )

    (var-set appraisal-counter new-appraisal-id)
    (ok new-appraisal-id)
  )
)

(define-public (renew-license (license-id uint) (duration-days uint))
  (let
    (
      (license-data (unwrap! (get-license license-id) ERR-INVALID-LICENSE))
      (fee-required (var-get base-fee))
      (new-expiration (+ block-height (* duration-days u144)))
    )
    (asserts! (is-eq tx-sender (get holder license-data)) ERR-NOT-AUTHORIZED)
    (asserts! (> duration-days u0) ERR-INVALID-INPUT)
    (asserts! (< duration-days u1095) ERR-INVALID-INPUT)

    (try! (stx-transfer? fee-required tx-sender (as-contract tx-sender)))

    (map-set licenses
      { license-id: license-id }
      (merge license-data {
        expiration-date: new-expiration,
        status: "active",
        fee-paid: (+ (get fee-paid license-data) fee-required)
      })
    )

    (ok true)
  )
)

(define-public (update-certifications (license-id uint) (new-certifications (list 3 (string-ascii 20))))
  (let
    (
      (license-data (unwrap! (get-license license-id) ERR-INVALID-LICENSE))
    )
    (asserts! (is-eq tx-sender (get holder license-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-license-valid license-id) ERR-EXPIRED)

    (map-set licenses
      { license-id: license-id }
      (merge license-data { certifications: new-certifications })
    )

    (ok true)
  )
)

(define-public (dispute-appraisal (appraisal-id uint))
  (let
    (
      (appraisal-data (unwrap! (get-appraisal appraisal-id) ERR-INVALID-INPUT))
    )
    (asserts! (is-eq tx-sender (get client appraisal-data)) ERR-NOT-AUTHORIZED)

    (map-set appraisals
      { appraisal-id: appraisal-id }
      (merge appraisal-data { status: "disputed" })
    )

    (ok true)
  )
)

(define-public (suspend-license (license-id uint))
  (let
    (
      (license-data (unwrap! (get-license license-id) ERR-INVALID-LICENSE))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set licenses
      { license-id: license-id }
      (merge license-data { status: "suspended" })
    )

    (ok true)
  )
)

(define-public (revoke-license (license-id uint))
  (let
    (
      (license-data (unwrap! (get-license license-id) ERR-INVALID-LICENSE))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set licenses
      { license-id: license-id }
      (merge license-data { status: "revoked" })
    )

    (ok true)
  )
)

(define-public (update-base-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)
    (var-set base-fee new-fee)
    (ok true)
  )
)
