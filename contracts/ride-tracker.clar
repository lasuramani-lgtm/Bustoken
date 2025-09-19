;; title: ride-tracker
;; version: 1.0.0
;; summary: Bus Token System - Ride Tracking Contract
;; description: Tracks individual bus rides, journey analytics, and passenger travel history

;; constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_RIDE_NOT_FOUND (err u201))
(define-constant ERR_RIDE_ALREADY_COMPLETED (err u202))
(define-constant ERR_INVALID_TICKET (err u203))
(define-constant ERR_INVALID_STOP (err u204))
(define-constant ERR_ROUTE_NOT_FOUND (err u205))
(define-constant ERR_JOURNEY_IN_PROGRESS (err u206))
(define-constant ERR_INVALID_OPERATOR (err u207))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_STOPS_PER_ROUTE u50)

;; data vars
(define-data-var ride-counter uint u0)
(define-data-var total-journeys uint u0)
(define-data-var total-distance-tracked uint u0)
(define-data-var system-active bool true)

;; data maps
(define-map rides
  { ride-id: uint }
  {
    ticket-id: uint,
    passenger: principal,
    operator: principal,
    route-id: uint,
    boarding-stop: uint,
    destination-stop: (optional uint),
    boarding-time: uint,
    completion-time: (optional uint),
    journey-distance: (optional uint),
    fare-paid: uint,
    is-completed: bool
  }
)

(define-map route-stops
  { route-id: uint, stop-id: uint }
  {
    stop-name: (string-ascii 50),
    stop-order: uint,
    distance-from-start: uint,
    is-active: bool
  }
)

(define-map passenger-journeys
  { passenger: principal }
  {
    total-rides: uint,
    total-distance: uint,
    total-spent: uint,
    favorite-route: (optional uint),
    last-ride: (optional uint)
  }
)

(define-map operator-performance
  { operator: principal }
  {
    total-rides-handled: uint,
    total-revenue-generated: uint,
    routes-operated: (list 10 uint),
    average-rating: uint,
    last-active: uint
  }
)

(define-map route-analytics
  { route-id: uint }
  {
    total-rides: uint,
    total-passengers: uint,
    total-revenue: uint,
    peak-hours: (list 5 uint),
    popular-stops: (list 10 uint),
    average-journey-time: uint
  }
)

(define-map daily-stats
  { date: uint }
  {
    total-rides: uint,
    total-passengers: uint,
    total-revenue: uint,
    busiest-route: (optional uint),
    peak-hour: (optional uint)
  }
)

;; private functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (increment-ride-counter)
  (let ((current-counter (var-get ride-counter)))
    (var-set ride-counter (+ current-counter u1))
    current-counter
  )
)

(define-private (calculate-journey-distance (route-id uint) (start-stop uint) (end-stop uint))
  (let
    (
      (start-data (map-get? route-stops { route-id: route-id, stop-id: start-stop }))
      (end-data (map-get? route-stops { route-id: route-id, stop-id: end-stop }))
    )
    (match start-data
      start-info
      (match end-data
        end-info
        (let
          (
            (start-distance (get distance-from-start start-info))
            (end-distance (get distance-from-start end-info))
          )
          (if (> end-distance start-distance)
            (- end-distance start-distance)
            (- start-distance end-distance)
          )
        )
        u0
      )
      u0
    )
  )
)

(define-private (update-passenger-journey-stats (passenger principal) (distance uint) (fare uint))
  (let
    (
      (current-stats (default-to
        { total-rides: u0, total-distance: u0, total-spent: u0, favorite-route: none, last-ride: none }
        (map-get? passenger-journeys { passenger: passenger })
      ))
      (new-ride-id (var-get ride-counter))
    )
    (map-set passenger-journeys
      { passenger: passenger }
      {
        total-rides: (+ (get total-rides current-stats) u1),
        total-distance: (+ (get total-distance current-stats) distance),
        total-spent: (+ (get total-spent current-stats) fare),
        favorite-route: (get favorite-route current-stats),
        last-ride: (some new-ride-id)
      }
    )
  )
)

(define-private (update-operator-performance (operator principal) (revenue uint))
  (let
    (
      (current-perf (default-to
        { total-rides-handled: u0, total-revenue-generated: u0, routes-operated: (list), average-rating: u0, last-active: u0 }
        (map-get? operator-performance { operator: operator })
      ))
    )
    (map-set operator-performance
      { operator: operator }
      {
        total-rides-handled: (+ (get total-rides-handled current-perf) u1),
        total-revenue-generated: (+ (get total-revenue-generated current-perf) revenue),
        routes-operated: (get routes-operated current-perf),
        average-rating: (get average-rating current-perf),
        last-active: stacks-block-height
      }
    )
  )
)

;; public functions
(define-public (start-journey (ticket-id uint) (route-id uint) (boarding-stop uint) (fare-paid uint))
  (let
    (
      (ride-id (increment-ride-counter))
    )
    (asserts! (var-get system-active) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? route-stops { route-id: route-id, stop-id: boarding-stop })) ERR_INVALID_STOP)
    
    ;; Record the ride start
    (map-set rides
      { ride-id: ride-id }
      {
        ticket-id: ticket-id,
        passenger: tx-sender,
        operator: tx-sender, ;; In real implementation, this would be the bus operator
        route-id: route-id,
        boarding-stop: boarding-stop,
        destination-stop: none,
        boarding-time: stacks-block-height,
        completion-time: none,
        journey-distance: none,
        fare-paid: fare-paid,
        is-completed: false
      }
    )
    
    ;; Update total journeys counter
    (var-set total-journeys (+ (var-get total-journeys) u1))
    
    (ok ride-id)
  )
)

(define-public (complete-journey (ride-id uint) (destination-stop uint))
  (let
    (
      (ride-data (unwrap! (map-get? rides { ride-id: ride-id }) ERR_RIDE_NOT_FOUND))
      (journey-distance (calculate-journey-distance
                          (get route-id ride-data)
                          (get boarding-stop ride-data)
                          destination-stop))
    )
    (asserts! (not (get is-completed ride-data)) ERR_RIDE_ALREADY_COMPLETED)
    (asserts! (or (is-eq tx-sender (get passenger ride-data)) (is-eq tx-sender (get operator ride-data))) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? route-stops { route-id: (get route-id ride-data), stop-id: destination-stop })) ERR_INVALID_STOP)
    
    ;; Update ride record
    (map-set rides
      { ride-id: ride-id }
      (merge ride-data
        {
          destination-stop: (some destination-stop),
          completion-time: (some stacks-block-height),
          journey-distance: (some journey-distance),
          is-completed: true
        }
      )
    )
    
    ;; Update passenger journey statistics
    (update-passenger-journey-stats (get passenger ride-data) journey-distance (get fare-paid ride-data))
    
    ;; Update operator performance
    (update-operator-performance (get operator ride-data) (get fare-paid ride-data))
    
    ;; Update total distance tracked
    (var-set total-distance-tracked (+ (var-get total-distance-tracked) journey-distance))
    
    (ok true)
  )
)

(define-public (add-route-stop (route-id uint) (stop-id uint) (stop-name (string-ascii 50)) (stop-order uint) (distance-from-start uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    
    (map-set route-stops
      { route-id: route-id, stop-id: stop-id }
      {
        stop-name: stop-name,
        stop-order: stop-order,
        distance-from-start: distance-from-start,
        is-active: true
      }
    )
    
    (ok true)
  )
)

(define-public (update-route-analytics (route-id uint) (passenger-count uint) (revenue uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    
    (let
      (
        (current-analytics (default-to
          { total-rides: u0, total-passengers: u0, total-revenue: u0, peak-hours: (list), popular-stops: (list), average-journey-time: u0 }
          (map-get? route-analytics { route-id: route-id })
        ))
      )
      (map-set route-analytics
        { route-id: route-id }
        {
          total-rides: (+ (get total-rides current-analytics) u1),
          total-passengers: (+ (get total-passengers current-analytics) passenger-count),
          total-revenue: (+ (get total-revenue current-analytics) revenue),
          peak-hours: (get peak-hours current-analytics),
          popular-stops: (get popular-stops current-analytics),
          average-journey-time: (get average-journey-time current-analytics)
        }
      )
    )
    
    (ok true)
  )
)

(define-public (record-daily-stats (date uint) (total-rides uint) (total-passengers uint) (total-revenue uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    
    (map-set daily-stats
      { date: date }
      {
        total-rides: total-rides,
        total-passengers: total-passengers,
        total-revenue: total-revenue,
        busiest-route: none,
        peak-hour: none
      }
    )
    
    (ok true)
  )
)

(define-public (toggle-system (active bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set system-active active)
    (ok active)
  )
)

;; read only functions
(define-read-only (get-ride-info (ride-id uint))
  (map-get? rides { ride-id: ride-id })
)

(define-read-only (get-route-stop-info (route-id uint) (stop-id uint))
  (map-get? route-stops { route-id: route-id, stop-id: stop-id })
)

(define-read-only (get-passenger-journey-stats (passenger principal))
  (map-get? passenger-journeys { passenger: passenger })
)

(define-read-only (get-operator-performance (operator principal))
  (map-get? operator-performance { operator: operator })
)

(define-read-only (get-route-analytics (route-id uint))
  (map-get? route-analytics { route-id: route-id })
)

(define-read-only (get-daily-stats (date uint))
  (map-get? daily-stats { date: date })
)

(define-read-only (get-journey-summary (ride-id uint))
  (match (get-ride-info ride-id)
    ride-data
    {
      exists: true,
      passenger: (get passenger ride-data),
      route-id: (get route-id ride-data),
      boarding-stop: (get boarding-stop ride-data),
      destination-stop: (get destination-stop ride-data),
      journey-distance: (get journey-distance ride-data),
      duration-blocks: (match (get completion-time ride-data)
                         completion-time (- completion-time (get boarding-time ride-data))
                         u0),
      fare-paid: (get fare-paid ride-data),
      is-completed: (get is-completed ride-data)
    }
    {
      exists: false,
      passenger: CONTRACT_OWNER,
      route-id: u0,
      boarding-stop: u0,
      destination-stop: none,
      journey-distance: none,
      duration-blocks: u0,
      fare-paid: u0,
      is-completed: false
    }
  )
)

(define-read-only (get-system-stats)
  {
    total-rides: (var-get ride-counter),
    total-journeys: (var-get total-journeys),
    total-distance-tracked: (var-get total-distance-tracked),
    system-active: (var-get system-active),
    current-block: stacks-block-height
  }
)

(define-read-only (is-journey-active (ride-id uint))
  (match (get-ride-info ride-id)
    ride-data (not (get is-completed ride-data))
    false
  )
)

(define-read-only (get-passenger-active-rides (passenger principal))
  ;; In a real implementation, this would iterate through rides
  ;; For now, return basic info from passenger journey stats
  (match (get-passenger-journey-stats passenger)
    stats (get last-ride stats)
    none
  )
)

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)
