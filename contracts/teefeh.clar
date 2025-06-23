
;; GitGig - Decentralized Freelance Platform
;; A smart contract for managing freelance gigs, payments, and reputation on Stacks blockchain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-insufficient-payment (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-invalid-rating (err u106))

;; Gig status constants
(define-constant status-open u0)
(define-constant status-in-progress u1)
(define-constant status-completed u2)
(define-constant status-cancelled u3)
(define-constant status-disputed u4)

;; Data Variables
(define-data-var next-gig-id uint u1)
(define-data-var next-user-id uint u1)

;; Data Maps
;; User profiles
(define-map users
  { user-address: principal }
  {
    user-id: uint,
    username: (string-ascii 50),
    user-type: (string-ascii 20), ;; "freelancer", "client", or "both"
    total-rating: uint,
    rating-count: uint,
    gigs-completed: uint,
    is-active: bool
  }
)

;; Gig listings
(define-map gigs
  { gig-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    budget: uint,
    client: principal,
    freelancer: (optional principal),
    status: uint,
    created-at: uint,
    deadline: uint,
    escrow-amount: uint
  }
)

;; Gig applications
(define-map applications
  { gig-id: uint, applicant: principal }
  {
    proposal: (string-ascii 300),
    proposed-budget: uint,
    applied-at: uint
  }
)

;; Ratings and reviews
(define-map reviews
  { gig-id: uint, reviewer: principal }
  {
    rating: uint, ;; 1-5 stars
    review-text: (string-ascii 300),
    reviewed-at: uint
  }
)

;; Escrow balances
(define-map escrow
  { gig-id: uint }
  { amount: uint, locked: bool }
)

;; Private Functions

;; Get current block height as timestamp
(define-private (get-current-time)
  block-height
)

;; Check if user exists
(define-private (user-exists (user principal))
  (is-some (map-get? users { user-address: user }))
)

;; Check if gig exists
(define-private (gig-exists (gig-id uint))
  (is-some (map-get? gigs { gig-id: gig-id }))
)

;; Public Functions

;; Register a new user
(define-public (register-user (username (string-ascii 50)) (user-type (string-ascii 20)))
  (let ((user-address tx-sender)
        (current-user-id (var-get next-user-id)))
    (asserts! (not (user-exists user-address)) err-already-exists)
    (asserts! (or (is-eq user-type "freelancer")
                  (is-eq user-type "client")
                  (is-eq user-type "both")) err-invalid-status)

    (map-set users
      { user-address: user-address }
      {
        user-id: current-user-id,
        username: username,
        user-type: user-type,
        total-rating: u0,
        rating-count: u0,
        gigs-completed: u0,
        is-active: true
      }
    )
    (var-set next-user-id (+ current-user-id u1))
    (ok current-user-id)
  )
)

;; Create a new gig
(define-public (create-gig
  (title (string-ascii 100))
  (description (string-ascii 500))
  (budget uint)
  (deadline uint))
  (let ((gig-id (var-get next-gig-id))
        (client tx-sender))
    (asserts! (user-exists client) err-not-found)
    (asserts! (> budget u0) err-insufficient-payment)
    (asserts! (> deadline (get-current-time)) err-invalid-status)

    (map-set gigs
      { gig-id: gig-id }
      {
        title: title,
        description: description,
        budget: budget,
        client: client,
        freelancer: none,
        status: status-open,
        created-at: (get-current-time),
        deadline: deadline,
        escrow-amount: u0
      }
    )
    (var-set next-gig-id (+ gig-id u1))
    (ok gig-id)
  )
)

;; Apply to a gig
(define-public (apply-to-gig
  (gig-id uint)
  (proposal (string-ascii 300))
  (proposed-budget uint))
  (let ((applicant tx-sender)
        (gig-data (unwrap! (map-get? gigs { gig-id: gig-id }) err-not-found)))
    (asserts! (user-exists applicant) err-not-found)
    (asserts! (is-eq (get status gig-data) status-open) err-invalid-status)
    (asserts! (not (is-eq applicant (get client gig-data))) err-unauthorized)
    (asserts! (> proposed-budget u0) err-insufficient-payment)

    (map-set applications
      { gig-id: gig-id, applicant: applicant }
      {
        proposal: proposal,
        proposed-budget: proposed-budget,
        applied-at: (get-current-time)
      }
    )
    (ok true)
  )
)
;; Accept a freelancer for a gig
(define-public (accept-freelancer (gig-id uint) (freelancer principal))
  (let ((gig-data (unwrap! (map-get? gigs { gig-id: gig-id }) err-not-found))
        (client tx-sender))
    (asserts! (is-eq client (get client gig-data)) err-unauthorized)
    (asserts! (is-eq (get status gig-data) status-open) err-invalid-status)
    (asserts! (user-exists freelancer) err-not-found)
    (asserts! (is-some (map-get? applications { gig-id: gig-id, applicant: freelancer })) err-not-found)

    (map-set gigs
      { gig-id: gig-id }
      (merge gig-data {
        freelancer: (some freelancer),
        status: status-in-progress
      })
    )
    (ok true)
  )
)

;; Fund escrow for a gig
(define-public (fund-escrow (gig-id uint))
  (let ((gig-data (unwrap! (map-get? gigs { gig-id: gig-id }) err-not-found))
        (client tx-sender)
        (budget (get budget gig-data)))
    (asserts! (is-eq client (get client gig-data)) err-unauthorized)
    (asserts! (is-eq (get status gig-data) status-in-progress) err-invalid-status)
    (asserts! (> budget u0) err-insufficient-payment)

    ;; Transfer STX to contract for escrow
    (try! (stx-transfer? budget client (as-contract tx-sender)))

    (map-set escrow
      { gig-id: gig-id }
      { amount: budget, locked: true }
    )

    (map-set gigs
      { gig-id: gig-id }
      (merge gig-data { escrow-amount: budget })
    )
    (ok true)
  )
)

;; Complete a gig and release payment
(define-public (complete-gig (gig-id uint))
  (let ((gig-data (unwrap! (map-get? gigs { gig-id: gig-id }) err-not-found))
        (escrow-data (unwrap! (map-get? escrow { gig-id: gig-id }) err-not-found))
        (freelancer-principal (unwrap! (get freelancer gig-data) err-not-found)))
    (asserts! (is-eq tx-sender (get client gig-data)) err-unauthorized)
    (asserts! (is-eq (get status gig-data) status-in-progress) err-invalid-status)
    (asserts! (get locked escrow-data) err-invalid-status)

    ;; Release payment to freelancer
    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender freelancer-principal)))

    ;; Update gig status
    (map-set gigs
      { gig-id: gig-id }
      (merge gig-data { status: status-completed })
    )

    ;; Update escrow
    (map-set escrow
      { gig-id: gig-id }
      { amount: u0, locked: false }
    )

    ;; Update user stats
    (update-user-completion freelancer-principal)
    (update-user-completion (get client gig-data))

    (ok true)
  )
)

;; Rate and review a completed gig
(define-public (rate-gig
  (gig-id uint)
  (rating uint)
  (review-text (string-ascii 300)))
  (let ((gig-data (unwrap! (map-get? gigs { gig-id: gig-id }) err-not-found))
        (reviewer tx-sender))
    (asserts! (is-eq (get status gig-data) status-completed) err-invalid-status)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (or (is-eq reviewer (get client gig-data))
                  (is-eq reviewer (unwrap! (get freelancer gig-data) err-not-found))) err-unauthorized)

    (map-set reviews
      { gig-id: gig-id, reviewer: reviewer }
      {
        rating: rating,
        review-text: review-text,
        reviewed-at: (get-current-time)
      }
    )

    ;; Update rating for the other party
    (let ((rated-user (if (is-eq reviewer (get client gig-data))
                         (unwrap! (get freelancer gig-data) err-not-found)
                         (get client gig-data))))
      (update-user-rating rated-user rating)
    )

    (ok true)
  )
)
;; Helper function to update user completion count
(define-private (update-user-completion (user principal))
  (let ((user-data (unwrap! (map-get? users { user-address: user }) err-not-found)))
    (map-set users
      { user-address: user }
      (merge user-data {
        gigs-completed: (+ (get gigs-completed user-data) u1)
      })
    )
    (ok true)
  )
)

;; Helper function to update user rating
(define-private (update-user-rating (user principal) (new-rating uint))
  (let ((user-data (unwrap! (map-get? users { user-address: user }) err-not-found))
        (current-total (get total-rating user-data))
        (current-count (get rating-count user-data))
        (new-total (+ current-total new-rating))
        (new-count (+ current-count u1)))
    (map-set users
      { user-address: user }
      (merge user-data {
        total-rating: new-total,
        rating-count: new-count
      })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get user profile
(define-read-only (get-user (user-address principal))
  (map-get? users { user-address: user-address })
)

;; Get gig details
(define-read-only (get-gig (gig-id uint))
  (map-get? gigs { gig-id: gig-id })
)

;; Get application details
(define-read-only (get-application (gig-id uint) (applicant principal))
  (map-get? applications { gig-id: gig-id, applicant: applicant })
)

;; Get review details
(define-read-only (get-review (gig-id uint) (reviewer principal))
  (map-get? reviews { gig-id: gig-id, reviewer: reviewer })
)

;; Get escrow details
(define-read-only (get-escrow (gig-id uint))
  (map-get? escrow { gig-id: gig-id })
)

;; Get user's average rating
(define-read-only (get-user-average-rating (user-address principal))
  (let ((user-data (map-get? users { user-address: user-address })))
    (match user-data
      user-info
        (let ((total (get total-rating user-info))
              (count (get rating-count user-info)))
          (if (> count u0)
            (some (/ total count))
            (some u0)))
      none
    )
  )
)

;; Get next gig ID
(define-read-only (get-next-gig-id)
  (var-get next-gig-id)
)

;; Get next user ID
(define-read-only (get-next-user-id)
  (var-get next-user-id)
)
