;; Asset Registration Contract
;; Records details of industrial equipment

(define-data-var last-asset-id uint u0)

(define-map assets
  { asset-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    model: (string-ascii 100),
    manufacturer: (string-ascii 100),
    installation-date: uint,
    active: bool
  }
)

(define-public (register-asset
    (name (string-ascii 100))
    (model (string-ascii 100))
    (manufacturer (string-ascii 100))
    (installation-date uint))
  (let
    (
      (new-asset-id (+ (var-get last-asset-id) u1))
    )
    (var-set last-asset-id new-asset-id)
    (map-set assets
      { asset-id: new-asset-id }
      {
        owner: tx-sender,
        name: name,
        model: model,
        manufacturer: manufacturer,
        installation-date: installation-date,
        active: true
      }
    )
    (ok new-asset-id)
  )
)

(define-public (update-asset
    (asset-id uint)
    (name (string-ascii 100))
    (model (string-ascii 100))
    (manufacturer (string-ascii 100))
    (installation-date uint))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) (err u404)))
    )
    (asserts! (is-eq tx-sender (get owner asset)) (err u403))
    (map-set assets
      { asset-id: asset-id }
      (merge asset {
        name: name,
        model: model,
        manufacturer: manufacturer,
        installation-date: installation-date
      })
    )
    (ok true)
  )
)

(define-public (transfer-asset (asset-id uint) (new-owner principal))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) (err u404)))
    )
    (asserts! (is-eq tx-sender (get owner asset)) (err u403))
    (map-set assets
      { asset-id: asset-id }
      (merge asset { owner: new-owner })
    )
    (ok true)
  )
)

(define-public (deactivate-asset (asset-id uint))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) (err u404)))
    )
    (asserts! (is-eq tx-sender (get owner asset)) (err u403))
    (map-set assets
      { asset-id: asset-id }
      (merge asset { active: false })
    )
    (ok true)
  )
)

(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

(define-read-only (get-asset-owner (asset-id uint))
  (get owner (default-to
    {
      owner: tx-sender,
      name: "",
      model: "",
      manufacturer: "",
      installation-date: u0,
      active: false
    }
    (map-get? assets { asset-id: asset-id })
  ))
)
