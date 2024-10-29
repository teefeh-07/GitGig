;; GitGig - Decentralized Web3 Job Board
;; A platform for posting and applying to Web3 jobs with secure payment escrow

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-job (err u102))
(define-constant err-already-applied (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-invalid-input (err u105))
(define-constant min-payment u1000000) ;; Minimum payment in microSTX
(define-constant max-payment u1000000000) ;; Maximum payment in microSTX
(define-constant min-deadline u1440) ;; Minimum deadline (blocks, ~10 days)

;; Data Maps
(define-map Jobs
    { job-id: uint }
    {
        employer: principal,
        title: (string-utf8 256),
        description: (string-utf8 1024),
        payment: uint,
        status: (string-utf8 20),
        deadline: uint,
        required-skills: (list 10 (string-utf8 64))
    }
)

(define-map Applications
    { job-id: uint, applicant: principal }
    {
        proposal: (string-utf8 1024),
        status: (string-utf8 20),
        timestamp: uint
    }
)

(define-map JobCounter uint uint)

;; Private Functions
(define-private (is-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (validate-payment (payment uint))
    (and 
        (>= payment min-payment)
        (<= payment max-payment)
    )
)

(define-private (validate-deadline (deadline uint))
    (>= deadline (+ block-height min-deadline))
)

(define-private (validate-string-length-256 (str (string-utf8 256)))
    (and
        (>= (len str) u1)
        (<= (len str) u256)
    )
)

(define-private (validate-string-length-1024 (str (string-utf8 1024)))
    (and
        (>= (len str) u1)
        (<= (len str) u1024)
    )
)

(define-private (validate-skills (skills (list 10 (string-utf8 64))))
    (and
        (>= (len skills) u1)
        (<= (len skills) u10)
    )
)

;; Added validation function for job-id and applicant
(define-private (validate-application-params (job-id uint) (applicant principal))
    (and
        (>= job-id u1)
        (is-some (map-get? Jobs { job-id: job-id }))
        (not (is-eq applicant (get employer (unwrap! (map-get? Jobs { job-id: job-id }) false))))
    )
)

;; Public Functions
(define-public (post-job (title (string-utf8 256)) 
                        (description (string-utf8 1024)) 
                        (payment uint)
                        (deadline uint)
                        (required-skills (list 10 (string-utf8 64))))
    (let
        (
            (job-id (default-to u0 (get-job-counter)))
            (new-id (+ job-id u1))
        )
        ;; Input validation
        (asserts! (validate-string-length-256 title) err-invalid-input)
        (asserts! (validate-string-length-1024 description) err-invalid-input)
        (asserts! (validate-payment payment) err-invalid-input)
        (asserts! (validate-deadline deadline) err-invalid-input)
        (asserts! (validate-skills required-skills) err-invalid-input)

        (try! (stx-transfer? payment tx-sender (as-contract tx-sender)))
        (map-set Jobs
            { job-id: new-id }
            {
                employer: tx-sender,
                title: title,
                description: description,
                payment: payment,
                status: u"open",
                deadline: deadline,
                required-skills: required-skills
            }
        )
        (map-set JobCounter u0 new-id)
        (ok new-id)
    )
)

(define-public (apply-for-job (job-id uint) 
                             (proposal (string-utf8 1024)))
    (let
        (
            (job (unwrap! (map-get? Jobs { job-id: job-id }) err-not-found))
        )
        ;; Input validation
        (asserts! (validate-string-length-1024 proposal) err-invalid-input)
        (asserts! (validate-application-params job-id tx-sender) err-invalid-input)
        (asserts! (is-eq (get status job) u"open") err-invalid-job)
        (asserts! (is-none (map-get? Applications { job-id: job-id, applicant: tx-sender })) err-already-applied)
        (asserts! (< block-height (get deadline job)) err-invalid-job)

        (map-set Applications
            { job-id: job-id, applicant: tx-sender }
            {
                proposal: proposal,
                status: u"pending",
                timestamp: block-height
            }
        )
        (ok true)
    )
)

(define-public (accept-application (job-id uint) 
                                 (applicant principal))
    (let
        (
            (job (unwrap! (map-get? Jobs { job-id: job-id }) err-not-found))
            (application (unwrap! (map-get? Applications { job-id: job-id, applicant: applicant }) err-not-found))
        )
        ;; Input validation
        (asserts! (validate-application-params job-id applicant) err-invalid-input)
        (asserts! (is-eq tx-sender (get employer job)) err-owner-only)
        (asserts! (is-eq (get status job) u"open") err-invalid-job)
        (asserts! (is-eq (get status application) u"pending") err-invalid-job)

        (map-set Applications
            { job-id: job-id, applicant: applicant }
            {
                proposal: (get proposal application),
                status: u"accepted",
                timestamp: block-height
            }
        )
        (map-set Jobs
            { job-id: job-id }
            (merge job { status: u"filled" })
        )
        (ok true)
    )
)

(define-public (complete-job (job-id uint))
    (let
        (
            (job (unwrap! (map-get? Jobs { job-id: job-id }) err-not-found))
        )
        ;; Input validation
        (asserts! (>= job-id u1) err-invalid-input)
        (asserts! (is-eq tx-sender (get employer job)) err-owner-only)
        (asserts! (is-eq (get status job) u"filled") err-invalid-job)

        (try! (as-contract (stx-transfer? (get payment job) tx-sender (get employer job))))
        (map-set Jobs
            { job-id: job-id }
            (merge job { status: u"completed" })
        )
        (ok true)
    )
)

;; Read-Only Functions
(define-read-only (get-job-counter)
    (map-get? JobCounter u0)
)

(define-read-only (get-job (job-id uint))
    (map-get? Jobs { job-id: job-id })
)

(define-read-only (get-application (job-id uint) (applicant principal))
    (if (validate-application-params job-id applicant)
        (map-get? Applications { job-id: job-id, applicant: applicant })
        none
    )
)