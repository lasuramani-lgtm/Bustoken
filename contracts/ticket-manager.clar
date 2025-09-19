;; title: ticket-manager
;; version: 1.0.0
;; summary: Bus Token System - Ticket Management Contract
;; description: Core contract for managing digital bus tickets, pricing, and operator authorization

;; constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_TICKET_NOT_FOUND (err u101))
(define-constant ERR_TICKET_ALREADY_USED (err u102))
(define-constant ERR_TICKET_EXPIRED (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_OPERATOR_NOT_AUTHORIZED (err u105))
(define-constant ERR_INVALID_ROUTE (err u106))
(define-constant ERR_INVALID_PRICE (err u107))
(define-constant ERR_TICKET_TRANSFER_FAILED (err u108))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant BASE_TICKET_PRICE u1000000) ;; 1 STX in microSTX
(define-constant TICKET_VALIDITY_BLOCKS u1440) ;; ~24 hours
(define-constant MAX_ROUTES u100)

;; data vars
(define-data-var ticket-counter uint u0)
(define-data-var system-enabled bool true)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee

;; data maps
(define-map tickets
  { ticket-id: uint }
  {
    passenger: principal,
    route-id: uint,
    price-paid: uint,
    purchase-height: uint,
    expiry-height: uint,
    is-used: bool,
    operator-used: (optional principal),
    usage-height: (optional uint)
  }
)

(define-map bus-routes
  { route-id: uint }
  {
    route-name: (string-ascii 50),
    base-price: uint,
    distance-km: uint,
    is-active: bool,
    created-by: principal
  }
)

(define-map authorized-operators
  { operator: principal }
  {
    is-authorized: bool,
    routes-allowed: (list 20 uint),
    total-validations: uint,
    authorized-at: uint,
    authorized-by: principal
  }
)

(define-map passenger-stats
  { passenger: principal }
  {
    total-tickets: uint,
    total-spent: uint,
    last-purchase: uint,
    active-tickets: uint
  }
)

(define-map route-pricing
  { route-id: uint }
  {
    base-fare: uint,
    per-km-rate: uint,
    peak-multiplier: uint, ;; percentage (100 = no change, 150 = 50% increase)
    discount-bulk: uint    ;; percentage discount for bulk purchases
  }
)

;; private functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-operator (operator principal))
  (default-to false
    (get is-authorized (map-get? authorized-operators { operator: operator }))
  )
)

(define-private (is-route-valid (route-id uint))
  (is-some (map-get? bus-routes { route-id: route-id }))
)

(define-private (calculate-ticket-price (route-id uint) (is-peak bool))
  (let
    (
      (route-data (unwrap! (map-get? bus-routes { route-id: route-id }) u0))
      (pricing-data (map-get? route-pricing { route-id: route-id }))
      (base-price (get base-price route-data))
      (distance (get distance-km route-data))
    )
    (match pricing-data
      pricing
      (let
        (
          (calculated-price (+ (get base-fare pricing) (* (get per-km-rate pricing) distance)))
          (peak-adjusted (if is-peak
                           (/ (* calculated-price (get peak-multiplier pricing)) u100)
                           calculated-price))
        )
        peak-adjusted
      )
      base-price
    )
  )
)

(define-private (increment-ticket-counter)
  (let ((current-counter (var-get ticket-counter)))
    (var-set ticket-counter (+ current-counter u1))
    current-counter
  )
)

(define-private (update-passenger-stats (passenger principal) (amount uint))
  (let
    (
      (current-stats (default-to
        { total-tickets: u0, total-spent: u0, last-purchase: u0, active-tickets: u0 }
        (map-get? passenger-stats { passenger: passenger })
      ))
    )
    (map-set passenger-stats
      { passenger: passenger }
      {
        total-tickets: (+ (get total-tickets current-stats) u1),
        total-spent: (+ (get total-spent current-stats) amount),
        last-purchase: stacks-block-height,
        active-tickets: (+ (get active-tickets current-stats) u1)
      }
    )
  )
)

;; public functions
(define-public (purchase-ticket (route-id uint) (is-peak-hour bool))
  (let
    (
      (ticket-id (increment-ticket-counter))
      (ticket-price (calculate-ticket-price route-id is-peak-hour))
      (expiry-height (+ stacks-block-height TICKET_VALIDITY_BLOCKS))
    )
    (asserts! (var-get system-enabled) ERR_UNAUTHORIZED)
    (asserts! (is-route-valid route-id) ERR_INVALID_ROUTE)
    (asserts! (> ticket-price u0) ERR_INVALID_PRICE)
    
    ;; Transfer STX payment
    (try! (stx-transfer? ticket-price tx-sender CONTRACT_OWNER))
    
    ;; Create ticket record
    (map-set tickets
      { ticket-id: ticket-id }
      {
        passenger: tx-sender,
        route-id: route-id,
        price-paid: ticket-price,
        purchase-height: stacks-block-height,
        expiry-height: expiry-height,
        is-used: false,
        operator-used: none,
        usage-height: none
      }
    )
    
    ;; Update passenger statistics
    (update-passenger-stats tx-sender ticket-price)
    
    (ok ticket-id)
  )
)

(define-public (validate-ticket (ticket-id uint))
  (let
    (
      (ticket-data (unwrap! (map-get? tickets { ticket-id: ticket-id }) ERR_TICKET_NOT_FOUND))
    )
    (asserts! (is-authorized-operator tx-sender) ERR_OPERATOR_NOT_AUTHORIZED)
    (asserts! (not (get is-used ticket-data)) ERR_TICKET_ALREADY_USED)
    (asserts! (<= stacks-block-height (get expiry-height ticket-data)) ERR_TICKET_EXPIRED)
    
    ;; Mark ticket as used
    (map-set tickets
      { ticket-id: ticket-id }
      (merge ticket-data
        {
          is-used: true,
          operator-used: (some tx-sender),
          usage-height: (some stacks-block-height)
        }
      )
    )
    
    ;; Update operator validation count
    (let
      (
        (operator-data (unwrap! (map-get? authorized-operators { operator: tx-sender }) ERR_OPERATOR_NOT_AUTHORIZED))
      )
      (map-set authorized-operators
        { operator: tx-sender }
        (merge operator-data { total-validations: (+ (get total-validations operator-data) u1) })
      )
    )
    
    ;; Update passenger active tickets count
    (let
      (
        (passenger (get passenger ticket-data))
        (passenger-data (unwrap!
          (map-get? passenger-stats { passenger: passenger })
          ERR_TICKET_NOT_FOUND
        ))
      )
      (map-set passenger-stats
        { passenger: passenger }
        (merge passenger-data
          { active-tickets: (if (> (get active-tickets passenger-data) u0)
                              (- (get active-tickets passenger-data) u1)
                              u0) }
        )
      )
    )
    
    (ok true)
  )
)

(define-public (authorize-operator (operator principal) (allowed-routes (list 20 uint)))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set authorized-operators
      { operator: operator }
      {
        is-authorized: true,
        routes-allowed: allowed-routes,
        total-validations: u0,
        authorized-at: stacks-block-height,
        authorized-by: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (revoke-operator (operator principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (let
      (
        (operator-data (unwrap! (map-get? authorized-operators { operator: operator }) ERR_OPERATOR_NOT_AUTHORIZED))
      )
      (map-set authorized-operators
        { operator: operator }
        (merge operator-data { is-authorized: false })
      )
      (ok true)
    )
  )
)

(define-public (create-route (route-name (string-ascii 50)) (base-price uint) (distance-km uint))
  (let
    (
      (route-id (+ (var-get ticket-counter) u1000)) ;; Simple route ID generation
    )
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (> base-price u0) ERR_INVALID_PRICE)
    
    (map-set bus-routes
      { route-id: route-id }
      {
        route-name: route-name,
        base-price: base-price,
        distance-km: distance-km,
        is-active: true,
        created-by: tx-sender
      }
    )
    
    ;; Set default pricing
    (map-set route-pricing
      { route-id: route-id }
      {
        base-fare: base-price,
        per-km-rate: u50000, ;; 0.05 STX per km
        peak-multiplier: u120, ;; 20% increase during peak
        discount-bulk: u10     ;; 10% bulk discount
      }
    )
    
    (ok route-id)
  )
)

(define-public (update-route-pricing
    (route-id uint)
    (base-fare uint)
    (per-km-rate uint)
    (peak-multiplier uint)
    (discount-bulk uint)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-route-valid route-id) ERR_INVALID_ROUTE)
    
    (map-set route-pricing
      { route-id: route-id }
      {
        base-fare: base-fare,
        per-km-rate: per-km-rate,
        peak-multiplier: peak-multiplier,
        discount-bulk: discount-bulk
      }
    )
    
    (ok true)
  )
)

(define-public (toggle-system (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set system-enabled enabled)
    (ok enabled)
  )
)

;; read only functions
(define-read-only (get-ticket-info (ticket-id uint))
  (map-get? tickets { ticket-id: ticket-id })
)

(define-read-only (get-route-info (route-id uint))
  (map-get? bus-routes { route-id: route-id })
)

(define-read-only (get-operator-info (operator principal))
  (map-get? authorized-operators { operator: operator })
)

(define-read-only (get-passenger-stats (passenger principal))
  (map-get? passenger-stats { passenger: passenger })
)

(define-read-only (get-route-pricing (route-id uint))
  (map-get? route-pricing { route-id: route-id })
)

(define-read-only (calculate-fare (route-id uint) (is-peak bool))
  (calculate-ticket-price route-id is-peak)
)

(define-read-only (is-ticket-valid (ticket-id uint))
  (match (get-ticket-info ticket-id)
    ticket-data
    {
      exists: true,
      is-used: (get is-used ticket-data),
      is-expired: (> stacks-block-height (get expiry-height ticket-data)),
      passenger: (get passenger ticket-data),
      route-id: (get route-id ticket-data)
    }
    {
      exists: false,
      is-used: false,
      is-expired: false,
      passenger: CONTRACT_OWNER,
      route-id: u0
    }
  )
)

(define-read-only (get-ticket-counter)
  (var-get ticket-counter)
)

(define-read-only (is-system-enabled)
  (var-get system-enabled)
)

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)
