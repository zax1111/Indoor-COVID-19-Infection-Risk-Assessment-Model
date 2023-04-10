extensions [gis vid time csv profiler matrix]
__includes ["time-series.nls"]
globals [file-name mouse-clicked mouse-double-click clicked-turtle clicked-xcor clicked-ycor scale times dumy_setting paths-dataset full-iso shape-list prog prog_total _recording-save-file-name
  open closed optimal-path
  current_time product-counter nb-cust-out-tot nb-cust-no-pay tot-checkout-time avg-checkout-time  ;shopping
  diffusion-rate cough-frequency cough-airflow-angle cough-spread-dist-mean cough-spread-dist-sd speak-airflow-angle speak-spread-dist-mean speak-spread-dist-sd speak-droplet-num-mean speak-droplet-num-sd cough-droplet-num-mean cough-droplet-num-sd cough-times
  virions-per-ml virion-risk expectorate-height vol-breathe k    ;k for dose-response relationship
  Vt_diam3 Vt_diam6 Vt_diam12 Vt_diam20 Vt_diam28 Vt_diam36 Vt_diam45 Vt_diam62.5 Vt_diam87.5 Vt_diam112.5 Vt_diam137.5 Vt_diam175 Vt_diam225 Vt_diam375 Vt_diam750
  num-supply-vent ventil-movement-rate
  droplet-decay plastic-decay steel-decay
  fingers-to-cell-ratio fingers-to-face-ratio transfer-efficiency-surface-to-hand transfer-efficiency-hand-to-face counter-touch-frequency face-touch-frequency mask-effect-touching mask-effect-inhale
  M_asymp M_symp M_cough_droplets M_speak_droplets S_asymp S_symp S_cough_droplets S_speak_droplets beta_asymp beta_symp beta_cough_droplets beta_speak_droplets
  total-customers total-infected total-originally-infected first-infection-time avg-air-patch-virions avg-surface-patch-virions avg-exposure-time avg-distance patches-in-cone customers-in-close-contact avg-close-contact-exposure avg-inhaled-virions sum-inhaled-virions avg-touched-virions sum-touched-virions avg-total-virions sum-total-virions
  avg-air-contamination-list avg-surface-contamination-list customers-in-close-contact-list avg-exposure-time-list avg-distance-list avg-inhaled-virions-list sum-inhaled-virions-list avg-touched-virions-list sum-touched-virions-list avg-total-virions-list sum-total-virions-list tick-list time-list
  total-infected-list total-susceptible-list total-originally-infected-list total-customers-list percentage-of-probable-infections percentage-of-probable-infections-list
]
breed [nodes node]
breed [customers customer]
breed [airarrows airarrow]
customers-own [speedx speedy path current-path
  shopping-list nb-product-in-cart selected-strategy prob-for-change next-destination nb-moves
  checkout-selected checkout-time  shopping-status  exit-selected  ;for shopping activity  ;shopping-status includes "to-shopping", "list-finished", "reached-near-checkout-zone", "queuing"
  infected? infectious? symptomatic? vaccinated? mask?
  timesteps_exposed droplets-at-inf inhaled-virions close-contact-exposure
  virions-on-hand virions-to-facial-membranes total-virions-exposed
]
patches-own [node-end heat-path passed var var_t
  wall? entrance? floor? checkout-zone? checkout-station? open-status exit? furniture? counter? window? return-vent? supply-vent? outdoor? inaccessible-area?
  parent-patch f g h   ;; f=g+h
  product-id checkout-speed   ;for shopping activity
  return-vent supply-vent total-droplets virion-count transmission-risk
  droplets_size3 droplets_size6 droplets_size12 droplets_size20 droplets_size28 droplets_size36 droplets_size45 droplets_size62.5 droplets_size87.5 droplets_size112.5 droplets_size137.5 droplets_size175 droplets_size225 droplets_size375 droplets_size750
  additionalDroplets_size3 additionalDroplets_size6 additionalDroplets_size12 additionalDroplets_size20 additionalDroplets_size28 additionalDroplets_size36 additionalDroplets_size45 additionalDroplets_size62.5 additionalDroplets_size87.5 additionalDroplets_size112.5 additionalDroplets_size137.5 additionalDroplets_size175 additionalDroplets_size225 additionalDroplets_size375 additionalDroplets_size750
  heat-virion-count heat-transmission-risk
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; shp file import (for GIS etc.) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to shp-import
  set file-name user-file
  if file-name = false [stop]
  read-gis-datasets
  setup-world-envelope
  draw-world
  setup-paths-graph
end

to read-gis-datasets
  set paths-dataset  gis:load-dataset file-name
end

to setup-world-envelope
  let world (gis:envelope-of paths-dataset) ;; [ minimum-x maximum-x minimum-y maximum-y ]
  let zoom 1.05

    let x0 (item 0 world + item 1 world) / 2          let y0 (item 2 world + item 3 world) / 2
    let W0 zoom * (item 0 world - item 1 world) / 2   let H0 zoom * (item 2 world - item 3 world) / 2
    set world (list (x0 - W0) (x0 + W0) (y0 - H0) (y0 + H0))

  gis:set-world-envelope (world)
end

to setup-paths-graph
  set-default-shape nodes "circle"
  ask nodes [set size 0.1]
  foreach polylines-of paths-dataset 10 [ ?1 ->
    (foreach butlast ?1 butfirst ?1 [ [??1 ??2] -> if ??1 != ??2 [ ;; skip nodes on top of each other due to rounding
      let n1 new-node-at first ??1 last ??1
      let n2 new-node-at first ??2 last ??2
      ask n2 [ask patch-here [set node-end 1]]
      ask n1 [face n2 while [[node-end] of patch-here != 1] [ask patch-here [set pcolor white] fd 0.001]]
      ask patches [set node-end 0]
    ] ])
  ]
  ask nodes [die]
end

to-report new-node-at [x y] ; returns a node at x,y creating one if there isn't one there.
  let n nodes with [xcor = x and ycor = y]
  ifelse any? n [set n one-of n] [create-nodes 1 [setxy x y set size 2 set n self]]
  report n
end

to draw-world
  gis:set-drawing-color [255   0   0]    gis:draw paths-dataset 1
end

to-report polylines-of [dataset decimalplaces]
  let polylines gis:feature-list-of dataset                              ;; start with a features list
  set polylines map [ ?1 -> first ?1 ] map [ ?1 -> gis:vertex-lists-of ?1 ] polylines      ;; convert to virtex lists
  set polylines map [ ?1 -> map [ ??1 -> gis:location-of ??1 ] ?1 ] polylines                ;; convert to netlogo float coords.
  set polylines remove [] map [ ?1 -> remove [] ?1 ] polylines                    ;; remove empty poly-sets .. not visible
  set polylines map [ ?1 -> map [ ??1 -> map [ ???1 -> precision ???1 decimalplaces ] ??1 ] ?1 ] polylines        ;; round to decimalplaces
    ;; note: probably should break polylines with empty coord pairs in the middle of the polyline
  report polylines ;; Note: polylines with a few off-world points simply skip them.
end

to-report meters-per-patch ;; maybe should be in gis: extension?
  let world gis:world-envelope ; [ minimum-x maximum-x minimum-y maximum-y ]
  let x-meters-per-patch (item 1 world - item 0 world) / (max-pxcor - min-pxcor)
  let y-meters-per-patch (item 3 world - item 2 world) / (max-pycor - min-pycor)
  report mean list x-meters-per-patch y-meters-per-patch
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; make a movie ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to make-movie
  vid:reset-recorder
  let location (word user-new-file ".mov")
  if not is-string? location [ stop ]   ;; stop if user canceled
  set _recording-save-file-name location  ;; stop if user canceled
  vid:start-recorder

  while [ticks <= simulation_hours * 3600]
    [go vid:record-view]

  vid:record-view
  vid:save-recording _recording-save-file-name
  user-message (word "Exported movie to " location)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; for test ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to set-customers
  ask n-of customer-number patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [
    sprout-customers 1 [set shape "head" set size 0.5 set infected? true set infectious? true set color red]
  ]
end

to manual-move-customers
  if not mouse-clicked and mouse-down?
      [ifelse timer <= .25
         [set mouse-double-click true ]
         [set mouse-double-click false]
       reset-timer
       set mouse-clicked true
       if any? customers-on patch round mouse-xcor round mouse-ycor
         [set clicked-turtle one-of customers-on patch round mouse-xcor round mouse-ycor]
       ]

  if is-agent? clicked-turtle and not mouse-double-click
      [ask clicked-turtle [ setxy mouse-xcor mouse-ycor ]]

  if mouse-clicked and not mouse-down?
      [set mouse-clicked false
       if is-agent? clicked-turtle
       [ set clicked-turtle nobody]
      ]
end

to static-test
  if ticks >= simulation_hours * 3600 [stop]

  contaminate-exhale

  remove-droplets    ; air-based transmission
  if ventilation = true [move-air]
  diffuse-droplets   ; whether ventilation valid or not, always diffuse.
  inhale

  surface-cleaning
  virus-transfer-hand-to-face   ; surface-based transmission

  calculate-virions
  assess-distance
  assess-close-contact-exposures
  assess-air-contamination-level
  assess-surface-contamination-level
  assess-accumulated-inhaled-virions
  assess-accumulated-touched-virions
  assess-accumulated-total-virions
  assess-exposure-time-level

  record
  recolor-patch
  display-labels-customers
  display-labels-patches

  tick-advance dt   ;; tick-advance keeps consistant with "dt" in social force model, namely the smallest time step.   ;; Yet the diffusion process should be carefully calculated in a time step!
  update-plots   ;  since tick-advance does not update the plots.
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; set up ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  cd ct
  set-initial
  color-to-attribute
  set-product
  set-time
  set-droplets
  set-touch
  ask patches [
    set return-vent false ; all patches initially start out as a non-vent patch.
    set supply-vent false ; all patches initially start out as a non-vent patch.
  ]
  if ventilation = true [set-ventilation]
  set-agent-infection-status
  set-log-normal-distribution
  set mouse-clicked false
  set mouse-double-click false
  set clicked-turtle nobody

end

to set-initial
  ct
  clear-drawing
  clear-all-plots

  ask patches [set product-id 0 set checkout-speed 0      set var 0 set var_t 0]       ;; set initial shopping environment
  ask patches [
    set wall? false
    set entrance? false
    set checkout-zone? false
    set checkout-station? false
    set exit? false
    set furniture? false
    set counter? false
    set window? false
    set return-vent? false
    set supply-vent? false
    set outdoor? false
    set floor? false
    set inaccessible-area? false
    set open-status 0  set plabel ""  ; 0: close, 1: open, 3: to be closed
  ]
  set product-counter 0
  set total-customers 0
  set times 1
  set prog 0
  set prog_total 0
  reset-ticks
end

to color-to-attribute   ;write color to attribute
  ask patches [
    if pcolor = black [set wall? true]
    if pcolor = yellow [set entrance? true]
    if pcolor = 9 [set checkout-zone? true]
    if pcolor = red [set checkout-station? true]
    if pcolor = cyan [set exit? true set plabel "exit" set plabel-color 6]  ;to visualize "exit"
    if pcolor = 38 [set furniture? true]
    if pcolor = 36 [set counter? true]
    if pcolor = blue [set window? true]
    if pcolor = 115 [set return-vent? true]
    if pcolor = 117 [set supply-vent? true]
    if pcolor = 8 [set outdoor? true]
    if pcolor = white [set floor? true]
    if pcolor = 39 [set inaccessible-area? true]    ; inaccessible-are indictates area that man cannot walked in, but with air volume, here used for representing the shelves in a circle that customers cannot walk in.
  ]
end

to patch-color   ;used in the import-image button at the beginning
  ask patches with [pcolor != black and pcolor != cyan and pcolor != 38 and pcolor != 39 and pcolor != 36 and pcolor != blue and pcolor != yellow and pcolor != 9 and pcolor != red and pcolor != orange and pcolor != green and pcolor != 115 and pcolor != 117 and pcolor != 8]
                   [set pcolor white]
end

to set-product   ;; correlation product with space
  foreach sort patches with [furniture? = true] [the-patch ->
    ask the-patch [
      set product-id product-counter
      set product-counter product-counter + 1
    ]
  ]
end

to set-time
  set current_time time:anchor-to-ticks time:create "2022-09-16 09:00:00" 1 "second"   ;;; 1 tick = 1 second, 0.05 tick-advance = 0.05 second
end

to set-droplets
  set diffusion-rate 0.0015 / 60 * dt   ;Rate (%/tick-advance) at which droplets move to neighboring patches. *dt
  set cough-frequency 11.5 / 60 / 60 * dt   ;Probabilty (0 - 1) that symptomatic infectious individuals will cough each tick-advance. Note 11.5 is the times of cough per hour, so / 3600 * dt. "Lee, Kai K., et al. "Four-hour cough frequency monitoring in chronic cough." Chest 142.5 (2012): 1237-1243."
  set droplet-decay 0.5 / (1.09 * 60 * 60) * dt   ;Droplet/virion decay rate (% / tick-advance), simplified as a linear regression. 0.5 means half-life; after 1.09 hours, virions decrease 50%.  *dt.  Van Doremalen, Neeltje, et al. "Aerosol and surface stability of SARS-CoV-2 as compared with SARS-CoV-1." New England journal of medicine 382.16 (2020): 1564-1567.
  set plastic-decay 0.5 / (6.81 * 60 * 60) * dt
  set steel-decay 0.5 / (5.63 * 60 * 60) * dt
  set cough-airflow-angle 35   ;Angle (degree), mean and standard-deviation distance (m) of droplet cone spread when coughing.
  set cough-spread-dist-mean 5
  set cough-spread-dist-sd 0.256
  set speak-airflow-angle 63.5  ;Angle (degree), mean and standard-deviation distance (m) of droplet cone spread when NOT coughing (parameterized as "speaking" events).
  set speak-spread-dist-mean 0.55
  set speak-spread-dist-sd 0.068
  set cough-droplet-num-mean 970000
  set cough-droplet-num-sd 390000
  set speak-droplet-num-mean 970000
  set speak-droplet-num-sd 390000
  set virions-per-ml 2350000000   ;Number of virions present per mL of droplet fluid. 2.35*10^9.
  set k 410  ; k is the pathogen dependent parameter used in dose-response relationship, 4.1 * 10 ^ 2 PFU
  ;set virion-risk 0.0624    ;The probability that inhalation of a virion will result in infection for a susceptible individual.
  set expectorate-height 1.7  ;; The height (in m) at which droplets are expelled. This is also the maximum vertical height of the simulated world, and the height used to in area volume calculations. (i.e., patch volumes are 1 m X 1 m X expectorate-height m).
  set vol-breathe 2.1 / 60 / 60 * dt  ;Inhalation rate (cubic meters / tick-advance),  2.1 m3/hour for an adult, "Exposure Factors Handbook-CHAPTER06" (/ 3600 * dt)
  set cough-times 0

  set mask-effect-inhale 0.95
  set mask-effect-touching 0.33

  set Vt_diam3 0.000271406 ; The terminal velocity (m/s) of a respiratory droplet with a 3-micrometer diameter, calculated from equations given by Anchordopqui & Chudnovsky (2020) (Preprint available at https://arxiv.org/pdf/2003.13689.pdf).
  set Vt_diam6 0.001085622
  set Vt_diam12 0.004342489
  set Vt_diam20 0.012062469
  set Vt_diam28 0.02364244
  set Vt_diam36 0.0390824
  set Vt_diam45 0.06106625
  set Vt_diam62.5 0.11779755
  set Vt_diam87.5 0.230883198
  set Vt_diam112.5 0.381664063
  set Vt_diam137.5 0.570140143
  set Vt_diam175 0.923532793
  set Vt_diam225 1.52665625
  set Vt_diam375 4.240711806
  set Vt_diam750 16.96284722

end

to set-touch
  set fingers-to-cell-ratio 10 / 2500                     ; finger/patch area (for shelves needs to *5)
  set transfer-efficiency-surface-to-hand 0.003
  set fingers-to-face-ratio 0.2
  set transfer-efficiency-hand-to-face 0.35
  set counter-touch-frequency 0.2 / 60 * dt           ; assuming 0.2 times per min per person
  set face-touch-frequency 1024 / 26 / 4 / 60 / 60 * dt   ; based on the observation of 26 persons who collectively touched facial mucosal membranes unconsciously 1024 times in 4 h (0.16 times/min),  Kwok, Y.L., Gralton, J., McLaws, M.L., 2015. Face touching: a frequent habit that has implications for hand hygiene. Am. J. Infect. Control 43, 112–114.
end

to set-ventilation
  ask patches with [return-vent?] [set return-vent true]
  ask patches with [supply-vent?] [set supply-vent true]
  set num-supply-vent count patches with [supply-vent = true]
  ;;In this scenario, asuume the furniture, namely the store shelves is high with no air volume. Only floor area, waiting spaces have air volume.
  ask patches with [(not return-vent?) and (not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [sprout-airarrows 1 [set size 0.5]]   ;;exclude the outdoors
  ask airarrows [
    ifelse show-arrows = false
    [set hidden? true]
    [set color 8
      if [supply-vent] of patch-here = true [set color 98]]
    if count patches with [return-vent = true] > 0 [
      let closest-return-vent min-one-of patches with [return-vent = true] [distance myself]
      let next-neighbor min-one-of neighbors with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [distance closest-return-vent]
      face next-neighbor
      ;face closest-return-vent
    ]
  ]
end

to set-agent-infection-status   ;; set infection environment
  ask customers [
    set inhaled-virions 0
  ]
  set total-infected 0
  set total-originally-infected 0
  set percentage-of-probable-infections 0
  set first-infection-time "na"
  set avg-air-patch-virions 0
  set avg-surface-patch-virions 0
  set avg-exposure-time 0
  set avg-close-contact-exposure 0
  set avg-distance 0
  set customers-in-close-contact-list (list)
  set avg-distance-list (list)
  set avg-air-contamination-list (list)   ; remember to initialize list
  set avg-surface-contamination-list (list)
  set avg-inhaled-virions-list (list)
  set sum-inhaled-virions-list (list)
  set avg-touched-virions-list (list)
  set sum-touched-virions-list (list)
  set avg-total-virions-list (list)
  set sum-total-virions-list (list)
  set total-infected-list (list)
  set total-susceptible-list (list)
  set total-originally-infected-list (list)
  set total-customers-list (list)
  set percentage-of-probable-infections-list (list)
  set tick-list (list)
  set time-list (list)

  set avg-exposure-time-list (list)
end

to set-log-normal-distribution     ; Set up parameters for lognormal distributions based on instructions described in Exercise 7 of Ch. 15 (P214) of Agent-based and Individual-based Modeling: A Practical Introduction (Railsback & Grimm 2011).
  set beta_symp ln (1 + ((cough-spread-dist-sd ^ 2)/(cough-spread-dist-mean ^ 2))) ;This code defines the beta to be used in the step function (to draw from a lognormal distribution)
  set M_symp (ln(cough-spread-dist-mean) - (beta_symp / 2))  ;cough
  set S_symp sqrt beta_symp

  set beta_asymp ln (1 + ((speak-spread-dist-sd ^ 2)/(speak-spread-dist-mean ^ 2)))
  set M_asymp (ln(speak-spread-dist-mean) - (beta_asymp / 2))  ;speak
  set S_asymp sqrt beta_asymp

  set beta_cough_droplets ln (1 + ((cough-droplet-num-sd ^ 2)/(cough-droplet-num-mean ^ 2)))
  set M_cough_droplets (ln(cough-droplet-num-mean) - (beta_cough_droplets / 2))  ;cough
  set S_cough_droplets sqrt beta_cough_droplets

  set beta_speak_droplets ln (1 + ((speak-droplet-num-sd ^ 2)/(speak-droplet-num-mean ^ 2)))
  set M_speak_droplets (ln(speak-droplet-num-mean) - (beta_speak_droplets / 2))  ;speak
  set S_speak_droplets sqrt beta_speak_droplets
end

to draw-env
if mouse-down?
 [if draw-elements = "Erase(white)" [ask patch mouse-xcor mouse-ycor [set pcolor white]]
  if draw-elements = "Wall(black)" [ask patch mouse-xcor mouse-ycor [set pcolor black]]
  if draw-elements = "Exit(Cyan)" [ask patch mouse-xcor mouse-ycor [set pcolor cyan]]
  if draw-elements = "Furniture(38)" [ask patch mouse-xcor mouse-ycor [set pcolor 38]]
  if draw-elements = "Counter(36)" [ask patch mouse-xcor mouse-ycor [set pcolor 36]]
  if draw-elements = "Window(Blue)" [ask patch mouse-xcor mouse-ycor [set pcolor blue]]
  if draw-elements = "Entrance(Yellow)" [ask patch mouse-xcor mouse-ycor [set pcolor yellow]]
  if draw-elements = "CheckOutZone(gray9)" [ask patch mouse-xcor mouse-ycor [set pcolor 9]]
  if draw-elements = "CheckOutStation(red)" [ask patch mouse-xcor mouse-ycor [set pcolor red]]
  if draw-elements = "ReturnVent(115)" [ask patch mouse-xcor mouse-ycor [set pcolor 115]]
  if draw-elements = "SupplyVent(117)" [ask patch mouse-xcor mouse-ycor [set pcolor 117]]
  if draw-elements = "Outdoor(8)" [ask patch mouse-xcor mouse-ycor [set pcolor 8]]
  if draw-elements = "InaccessibleArea(39)" [ask patch mouse-xcor mouse-ycor [set pcolor 39]]
 ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Simulation ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to footprint
  if show_track = "Do not show"
  [pu]
  if show_track = "Show tracks" [pd]
end

to go
  if ticks >= simulation_hours * 3600 [stop]

  open-close-checkouts
  add-customer
  move-customer

  contaminate-exhale   ;

  remove-droplets    ; air-based transmission
  if ventilation = true [move-air]
  diffuse-droplets   ; whether ventilation valid or not, always diffuse.
  inhale

  surface-cleaning
  virus-transfer-hand-to-face   ; surface-based transmission

  calculate-virions
  assess-distance
  assess-close-contact-exposures
  assess-air-contamination-level
  assess-surface-contamination-level
  assess-accumulated-inhaled-virions
  assess-accumulated-touched-virions
  assess-accumulated-total-virions
  assess-exposure-time-level

  record
  recolor-patch
  display-labels-customers
  display-labels-patches

  ; if any? patches with [(virion-count > 0) and ((furniture?) or (counter?))] [stop]  ;;for checking the simulation process

  tick-advance dt   ;; tick-advance keeps consistant with "dt" in social force model, namely the smallest time step.   ;; Yet the diffusion process should be carefully calculated in a time step!
  update-plots   ;  since tick-advance does not update the plots.
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Task Flow (namely things to finish);;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Strategic and Tactical Level;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to open-close-checkouts
  let tot-checkouts count patches with [checkout-station?]
  let step-size 1 / tot-checkouts * 100
  if count patches with [open-status = 1] / tot-checkouts * 100 < percent-checkout-open [
    ask one-of patches with [(checkout-station?) and open-status != 1] [   ;;open 1 checkout every tick-advance
      set open-status 1
      set plabel "open"
      set plabel-color 6
      let speed avg-checkout-speed - 0.5 + random-float 1   ;; speed belongs to (aver-0.5, aver+0.5)
      set checkout-speed speed
    ]
  ]

  if count patches with [open-status = 1] / tot-checkouts * 100 - step-size > percent-checkout-open [  ;;step-size is used to avoid performing one more step, making it fall below the standard ,such as open 26% = open 3 of 10
    ask one-of patches with [open-status = 1] [set open-status 3]  ;;do not let people queue here 1 every tick
  ]
  ask patches with [open-status = 3] [   ;;if queue length = 0, turn it red
    let xorange pycor
    if count customers with [checkout-selected = xorange] = 0 [   ;; if queue, ycor = pycor exactly, excluded the customers in the store area
      set open-status 0
      set plabel ""
    ]
  ]
end

to add-customer
  if count customers < max-customer-number [
    if times mod (enter-interval / dt) = 0 [
      ask one-of patches with [entrance?] [
        sprout-customers 1 [
          set shape "head"
          set size 0.5
          set color gray
          define-shopping-list
          set nb-product-in-cart 0
          set selected-strategy random 3   ;; set the queue strategy random
          set prob-for-change random max-prob-for-change
          find-next-product
          set checkout-selected "None"
          set nb-moves 0
          set checkout-time 0
          set shopping-status "to-shopping"

          set mask? false
          set vaccinated? false
          set timesteps_exposed 0

          let infected-prob random-float 1     ; set infected status
          ifelse infected-prob <= infected-percentage
          [set infected? true
            set infectious? true
            set total-originally-infected total-originally-infected + 1  ;'implant tracker
            set color red
            let symptomatic-prob random-float 1
            ifelse symptomatic-prob <= symptomatic-percentage
            [set symptomatic? true]
            [set symptomatic? false]
          ]
          [set infected? false
            set infectious? false
          ]

          if mask-percentage > 0 [      ; set masked status
            let mask-prob random-float 1
            ifelse mask-prob <= mask-percentage
            [set mask? true]
            [set mask? false]
          ]

          if vaccinated-percentage > 0 [      ; set vaccinated status
            let vaccinated-prob random-float 1
            ifelse vaccinated-prob <= vaccinated-percentage
            [set vaccinated? true]
            [set vaccinated? false]
          ]

          set total-customers total-customers + 1
        ]
      ]
    ]
    set times times + 1
  ]
end

to define-shopping-list
  set shopping-list []
  let i 0
  let length-shopping-list (random (max-length-shopping-list - 1)) + 1
  loop [
    if i = length-shopping-list [stop]
    let selected-product (random (product-counter - 1)) + 1
    if not member? selected-product shopping-list [
      set shopping-list lput selected-product shopping-list
    ]
    set i i + 1
  ]
end

to find-next-product   ;; find the closest product in the store from shopping list
  let prev-dist 9999
  let prod-next 9999
  foreach shopping-list [id2 ->
    if distance-cust-to-prod id2 < prev-dist
    [set prod-next id2
      set prev-dist distance-cust-to-prod id2
    ]
  ]
  set next-destination prod-next
  ;face one-of patches with [product-id = prod-next]
end

to-report distance-cust-to-prod [id]   ;;; to better use the above anonymous procedure
  let dist 9999
  ask patches with [product-id = id] [
    set dist distance myself
  ]
  report dist
end

to move-customer
  ask customers [
    move-to-product
    pick-product
    move-to-checkout
    select-checkout

    enter-checkout-queue
    move-in-queue
    leave-without-paying
    pay
    leave
    set nb-moves nb-moves + 1  ;;nb-moves re'cord the number of customers' action
  ]
end

to move-to-product
  if shopping-status = "to-shopping" [
    let dest next-destination
    if not empty? shopping-list [
      set path find-a-path patch-here one-of patches with [product-id = dest]   ;; find the shortest path for the turtle, search every step in terms of the standing patch
      set current-path remove-item 0 path  ;; remove the first patch in the list so that the turtle can move
      if length current-path != 0 [
      face first current-path
      social-force-move
      ask patch-here [set passed passed + 1]
      ]
      footprint
    ]
  ]
end

to pick-product
  if not empty? shopping-list [
    let dest next-destination
    if distance one-of patches with [product-id = dest] < 2 [   ;; if reaching, remove product from the list.  Here define "reaching" as "distance < 2"

      virus-transfer-shelves-to-hands
      take-away-virus

      set nb-product-in-cart nb-product-in-cart + 1
      set shopping-list remove next-destination shopping-list
      find-next-product
      if empty? shopping-list [     ;;; if want to buy something when leaving, last minute addition
        ifelse random 100 < max-prob-for-change
            [let selected-product (random (product-counter - 1)) + 1
            set shopping-list lput selected-product shopping-list
            set next-destination selected-product]
            [set shopping-status "list-finished"]    ;;; if have picked up all things and do not want to buy anymore, turn green
        ]
      ]
    ]
end

to virus-transfer-shelves-to-hands
  if infected? = false and infectious? = false [      ;only ask uninfected person
    let fomite next-destination
    set virions-on-hand virions-on-hand + ([virion-count] of one-of patches with [product-id = fomite] * (fingers-to-cell-ratio / 5) * transfer-efficiency-surface-to-hand)
    ]
end

to take-away-virus
  let fomite next-destination
  ask one-of patches with [(product-id = fomite)] [
    set droplets_size3 droplets_size3 * 9 / 10
    set droplets_size6 droplets_size6 * 9 / 10
    set droplets_size12 droplets_size12 * 9 / 10
    set droplets_size20 droplets_size20 * 9 / 10
    set droplets_size28 droplets_size28 * 9 / 10
    set droplets_size36 droplets_size36 * 9 / 10
    set droplets_size45 droplets_size45 * 9 / 10
    set droplets_size62.5 droplets_size62.5 * 9 / 10
    set droplets_size87.5 droplets_size87.5 * 9 / 10
    set droplets_size112.5 droplets_size112.5 * 9 / 10
    set droplets_size137.5 droplets_size137.5 * 9 / 10
    set droplets_size175 droplets_size175 * 9 / 10
    set droplets_size225 droplets_size225 * 9 / 10
    set droplets_size375 droplets_size375 * 9 / 10
    set droplets_size750 droplets_size750 * 9 / 10
  ]
end

to select-checkout
  let closest-checkout-zone-patch min-one-of patches with [checkout-zone?] [distance myself]
  if shopping-status = "list-finished" and distance closest-checkout-zone-patch < 3 [
    if selected-strategy = 0 [   ;;random strategy
      if checkout-selected = "None" [
        set checkout-selected [pycor] of one-of patches with [(checkout-station?) and open-status = 1]
      ]
    ]
    if selected-strategy = 1 [   ;;closest checkout strategy
      let selection min-one-of patches with [(checkout-station?) and open-status = 1] [distance myself]
      set checkout-selected [pycor] of selection
    ]
    if selected-strategy = 2 [   ;;queue with less product in cart of waiting customers
      let min-nb 9999
      let selection 0
      ask patches with [(checkout-station?) and open-status = 1] [
        let nb 0
        ask customers with [checkout-selected = pycor] [
          set nb nb + nb-product-in-cart
        ]
        if nb < min-nb [
          set min-nb nb
          set selection pycor
        ]
      ]
        set checkout-selected selection
      ]
      if selected-strategy = 3 [   ;;queue with less customers
        let min-cust 9999
        let selection 0
        ask patches with [(checkout-station?) and open-status = 1] [
          let nb 9999
          let x pycor
          set nb count customers with [checkout-selected = x]
          if nb < min-cust [
            set min-cust nb
            set selection pycor
          ]
        ]
        set checkout-selected selection
      ]
      set shopping-status "reached-near-checkout-zone"   ;; orange indicates a person have reached near the checkout zone and selected a queue strategy
    ]
end

to move-to-checkout
  if shopping-status = "list-finished" or shopping-status = "reached-near-checkout-zone" [    ;; seperated into 2 phases
    ifelse shopping-status = "list-finished"
    [let closest-checkout-zone-patch min-one-of patches with [checkout-zone?] [distance myself]  ;; just move towards the checkout zone
      set path find-a-path patch-here closest-checkout-zone-patch
      set current-path remove-item 0 path
      if length current-path != 0 [
        face first current-path
        social-force-move
        ask patch-here [set passed passed + 1]
        footprint
      ]
    ]
    [let y checkout-selected
      let end-patch-selected-checkout max-one-of patches with [pycor = y and checkout-zone?] [pxcor]  ;; move towards the end of the selected checkout queue
      if distance end-patch-selected-checkout > (1) [
        set path find-a-path patch-here end-patch-selected-checkout
        set current-path remove-item 0 path
        if length current-path != 0 [
          face first current-path
          set checkout-time checkout-time + 1
        ]
        social-force-move
        ask patch-here [set passed passed + 1]
        footprint
      ]
     ]
  ]
end

to enter-checkout-queue
  let y checkout-selected
  let end-patch-selected-checkout max-one-of patches with [pycor = y and checkout-zone?] [pxcor]
  if shopping-status = "reached-near-checkout-zone" and distance end-patch-selected-checkout <= (1) [      ;;; ___Here is a jump action, the speed is 1m / tick-advance
    ifelse any? customers-on end-patch-selected-checkout
    [ifelse random 100 < customer-patience   ;; if the queue is full
      [set shopping-status "list-finished"     ;; decide to queue, and looking for new checkout the next tick/loop
        set checkout-selected "None"
        set selected-strategy 2]
      [let ycyan [pycor] of min-one-of patches with [exit?] [distance myself]   ;;assign the selected exit, choose the nearest exit   ;;decide to leave directly without paying
        set exit-selected ycyan
        set shopping-status "leaving"
      ]
    ]
    [face end-patch-selected-checkout   ;; if the queue is not full
      move-to end-patch-selected-checkout      ;;; ___move-to end-patch-selected-checkout exactly (ycor=pycor)
      set shopping-status "queuing"     ;;blue indicates the customer is in the queue
      ask patch-here [set passed passed + 1]
      set checkout-time checkout-time + 1
    ]
  ]
end

to move-in-queue
  let y checkout-selected
  let checkout-patch-selected patches with [checkout-station? and pycor = y]   ;; find the assigned checkout-station patch
  if shopping-status = "queuing" [
      if [checkout-zone?] of patch-here [
        facexy xcor - 1 ycor
        ifelse not any? customers-on checkout-patch-selected    ;
        [setxy (xcor - queueing-distance) ycor ]   ;
        [setxy xcor ycor]   ;; just stop/wait
        ask patch-here [set passed passed + 1]
      ]
    ]
  set checkout-time checkout-time + 1
end

to leave-without-paying
  if exit? [
    set nb-cust-out-tot nb-cust-out-tot + 1
    set nb-cust-no-pay nb-cust-no-pay + 1
    assess-infection-prob
    die
  ]
end

to pay
  if (checkout-station?) and (open-status = 1 or open-status = 3) [
    face min-one-of patches with [counter?] [distance myself]

    virus-transfer-counter-to-hands

    set nb-product-in-cart nb-product-in-cart - (checkout-speed * dt)  ;
    ask patch-here [set passed passed + 1]  ;; record the tick time or the number of people passed? actually record the "passed steps"
    if nb-product-in-cart <= 0 [
      set nb-cust-out-tot nb-cust-out-tot + 1
      set tot-checkout-time tot-checkout-time + checkout-time
      set avg-checkout-time tot-checkout-time / (nb-cust-out-tot - nb-cust-no-pay)

      set shopping-status "leaving"
      let ycyan [pycor] of min-one-of patches with [exit?] [distance myself]   ;;assign the selected exit, choose the nearest exit
      set exit-selected ycyan
      let exit-patch-selected one-of patches with [exit? and pycor = ycyan]
      move-to min-one-of neighbors with [floor?] [distance exit-patch-selected]
    ]
  ]
end

to leave
  if shopping-status = "leaving" [
    let ycyan exit-selected
    let exit-patch-selected one-of patches with [exit? and pycor = ycyan]
    set path find-a-path patch-here exit-patch-selected
    set current-path remove-item 0 path
    if length current-path != 0 [
      face first current-path
      social-force-move
      ask patch-here [set passed passed + 1]
      footprint
    ]
    if distance exit-patch-selected <= (1) [
      assess-infection-prob
      die
    ]
  ]
end


to virus-transfer-counter-to-hands
  if infected? = false and infectious? = false [      ;only ask uninfected person
    let fomite min-one-of patches with [counter?] [distance myself]
    set virions-on-hand virions-on-hand + ([virion-count] of fomite * fingers-to-cell-ratio * transfer-efficiency-surface-to-hand * counter-touch-frequency)    ;record the inhaled accumulated virions for uninfected persons.
    ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;Operational Level;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;; Target Walking (Floor Field) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report find-a-path [source-patch destination-patch]   ;; A* algorithm to find the shortest path
  let search-done? false
  let search-path []
  let current-patch 0
  set open []
  set closed []

  set open lput source-patch open
  while [search-done? != true]
  [ifelse length open != 0
    [set open sort-by [ [?1 ?2] -> [f] of ?1 < [f] of ?2 ] open    ;; sort the patches in openlist in increasing order of their f() values
      set current-patch item 0 open   ;; take the 1st patch in the open list as the current patch, and remove it from the open list
      set open remove-item 0 open
      set closed lput current-patch closed
      ask current-patch
      [ifelse any? neighbors with [(pxcor = [pxcor] of destination-patch) and (pycor = [pycor] of destination-patch)]
        [set search-done? true]
        [ask neighbors with [(not wall?) and (not window?) and (not furniture?) and (not counter?) and (not checkout-zone?) and (not checkout-station?) and (not inaccessible-area?) and (not exit?) and (not member? self closed) and (self != parent-patch)] [
          if not member? self open and self != source-patch and self != destination-patch [
            set open lput self open
            set parent-patch current-patch
            set g [g] of parent-patch + 1
            set h distance destination-patch
            set f (g + h)
          ]
         ]
        ]
      ]
    ]
    [user-message( "A path from the source to the destination does not exist.")
        report []]
  ]

  set search-path lput current-patch search-path   ;;if path is found, add the current patch to the search path
  let temp first search-path   ;; trace the search path from the current patch all the way to the source patch, using the parent patch variable which was set during the search for every patch that was explored
  while [temp != source-patch]
  [set search-path lput [parent-patch] of temp search-path
    set temp [parent-patch] of temp]
  set search-path fput destination-patch search-path  ;; add destination to the front
  set search-path reverse search-path  ;; reverse so that it starts from the patch adjacent to the source patch
  report search-path
end

to social-force-move
    let repx_turtles 0
    let repy_turtles 0
    let repx_envi 0
    let repy_envi 0
    let hd heading
    let h1 hd   ;; h will vary later, just to create a h here
    if not (speedx * speedy = 0)
      [set h1 atan speedx speedy]   ;; h is the direction of the patch
    ask customers in-radius (2 * D) with [not ((self = myself) or (abs (xcor - [xcor] of myself) + abs (ycor - [ycor] of myself) < 0.001))] ; self is me. myself is the agent who is asking me to do whatever I'm doing now.   ;; D is the Perceivable distance of a person, 0.5 looks reasonable indoor;  后面abs<0.001是去掉那些偶然走到完全一样的坐标上turtle，防止towards命令的bug
      [
        set repx_turtles repx_turtles + A * exp((2 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h1))   ;; repx = repulsive force in X direction, get the neighbourhood force to the Ped i; 2 = pedestrian size (1) *2
        set repy_turtles repy_turtles + A * exp((2 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h1))   ;; repy = repulsive force in Y direction
      ]
    ask other patches in-radius (2 * D) with [(not (self = myself)) and (wall? or window? or checkout-zone? or furniture? or counter? or exit? or checkout-station?)]
    [
        set repx_envi repx_envi + A * exp((1 - distance myself) / D) * sin(towards myself)    ; 1 = pedestrian size (1)
        set repy_envi repy_envi + A * exp((1 - distance myself) / D) * cos(towards myself)
    ]
    let repx repx_turtles + repx_envi
    let repy repy_turtles + repy_envi
    set speedx speedx + dt * (repx + (V0 * sin hd - speedx) / Tr)   ;; reflect the force in speed, speedx is the speed in X direction, V0 is the basic speed;; set the speed of the Ped A
    set speedy speedy + dt * (repy + (V0 * cos hd - speedy) / Tr)   ;; speedy is the speed in Y direction


  if (speedx * dt + speedy * dt != 0) [
    facexy (xcor + speedx * dt) (ycor + speedy * dt)
    let hd-sfm towardsxy (xcor + speedx * dt) (ycor + speedy * dt)

    if sqrt (speedx * speedx + speedy * speedy) > V0 [
      set speedx V0 * sin hd-sfm
      set speedy V0 * cos hd-sfm
    ]

    let move-angle subtract-headings hd hd-sfm
    ifelse abs move-angle > 120    ; here the angle can also be 90, but 90 degree makes many customers "pause"
    [ set xcor xcor
      set ycor ycor]
    [ let des-patch patch (xcor + speedx * dt) (ycor + speedy * dt)
      ifelse (des-patch = nobody) or ([wall?] of des-patch = true) or ([outdoor?] of des-patch = true) or ([furniture?] of des-patch = true) or ([counter?] of des-patch = true) or ([checkout-zone?] of des-patch = true) or ([inaccessible-area?] of des-patch = true)    ; 补充机制3：如果位移超出了world或者超出了人可移动范围(进入墙壁、家具、柜台、室外、inaccessible-area、checkout-zone、checkout-station)，则不动
      [ set xcor xcor
        set ycor ycor]
      [ set xcor xcor + speedx * dt   ;; set the next location of pedestrians
        set ycor ycor + speedy * dt]
    ]
  ]

end

to target-walking
  if any? neighbors with [not any? turtles-on self and (not wall?) and (not window?) and (not furniture?) and (not checkout-zone?) and (not checkout-station?) and (not exit?)]
      [face min-one-of neighbors with [not any? turtles-on self and (not wall?) and (not window?) and (not furniture?) and (not checkout-zone?) and (not checkout-station?) and (not exit?)] [var]  ;; face empty space with the lowest var
        social-force-move
        ask patch-here [set passed passed + 1]  ;;reflect the heat map of path
      ]
      footprint
end

to grade
  ;; if not any? patches with [exit?][user-message "NO EXIT" stop]
  ask patch-set patches [set var 0 set var_t 0]
  let x next-destination                 ;; transfer to a patch in a turtle context! not an observer context
  ask one-of patches with [product-id = x] [set var 1 set var_t 1]
  let var_t_t 2   ;; var_t_t is an initiative
  while [any? patches with [var_t != 0 and any? neighbors with [var = 0 and floor?]]]
         [ask patches with [var_t = var_t_t - 1]
           [ask neighbors [if var = 0 and (not wall?) and (not window?)
                              [set var_t var_t_t
                               let temp_grade min-one-of neighbors with [var_t = var_t_t - 1] [var]
                               set var [var] of temp_grade + distance temp_grade]  ;; var records the distance to the destination actually
                          ]
           ]
          set var_t_t var_t_t + 1
         ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Droplet Dynamics;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to contaminate-exhale
  ask customers with [infectious? = true] [    ;note here is infectious not infected
    let airflow-angle 0     ; to set "angle, distance and number" characteristic of droplets for 2 kinds of behaviors
    let spread-dist 0
    let droplet-num 0
    let cough-or-not 0
    ifelse symptomatic? = true
    [let cough-prob random-float 1    ;if symptomatic
      ifelse cough-prob <= cough-frequency     ;determine if cough at this tick/step for a symptomatic person
      [set cough-or-not 1      ; if cough
        set airflow-angle cough-airflow-angle
        set spread-dist exp (random-normal M_symp S_symp)  ;random generate a number follows log-normal distribution
        set droplet-num exp (random-normal M_cough_droplets S_cough_droplets)
        set cough-times cough-times + 1
      ]
      [set airflow-angle speak-airflow-angle    ;if not cough
        set spread-dist exp (random-normal M_asymp S_asymp)
        set droplet-num exp (random-normal M_speak_droplets S_speak_droplets)
      ]
    ]
    [set airflow-angle speak-airflow-angle  ;if asymptomatic
      set spread-dist exp (random-normal M_asymp S_asymp)
      set droplet-num exp (random-normal M_speak_droplets S_speak_droplets)
    ]

    if mask? = true [     ; if infectious individuals are wearing a mask, we assume that any droplets produced will never extend past the patch containing the infectious individual. 这就是 mask-effect-exhale
      set spread-dist 0
      ;set dropletNum (dropletNum * 0.1)   ; reduce the number of droplets by a fixed percentage if neccessary.
    ]

    set patches-in-cone patches in-cone spread-dist airflow-angle    ; track the present number of customers in danger (since the spread-dist and angle are only here valid)
    ask customers in-cone spread-dist airflow-angle [set close-contact-exposure close-contact-exposure + 1]   ;track the accumulated close-contact-exposure instances. Note "close-contact-exposure" is a customer's attibute.

    let contaminated-patch-count count patches in-cone spread-dist airflow-angle with [(not wall?) and (not outdoor?)]
    if contaminated-patch-count > 0 [
      let dropletDistrNum droplet-num / contaminated-patch-count  ;assume uniform quantity distribution in the cone
      ask patches in-cone spread-dist airflow-angle with [(not wall?) and (not outdoor?)] [
      if cough-or-not = 0 [
        if(speak_dropletSizeDistr = "chao")[         ; if the droplet size distribution will be defined by the Chao et al. (2009) paper, Characterization of expiration air jets and droplet size distributions immediately at the mouth opening.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0.10526316))  ;Add the number of droplets multiplied by the probability that droplets will be 2-4 (i.e., mean of 3) micrometers.
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.36842105))  ;Add the number of droplets multiplied by the probability that droplets will be 4-8 (i.e., mean of 6) micrometers.
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0.15789474))  ;Add the number of droplets multiplied by the probability that droplets will be 8-16 (i.e., mean of 12) micrometers.
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.098398169))  ;Add the number of droplets multiplied by the probability that droplets will be 16-24 (i.e., mean of 20) micrometers.
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0.059496568))  ;Add the number of droplets multiplied by the probability that droplets will be 24-32 (i.e., mean of 28) micrometers.
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0.043478261))  ;Add the number of droplets multiplied by the probability that droplets will be 32-40 (i.e., mean of 36) micrometers.
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.022883295))  ;Add the number of droplets multiplied by the probability that droplets will be 40-50 (i.e., mean of 45) micrometers.
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.032036613))  ;Add the number of droplets multiplied by the probability that droplets will be 50-75 (i.e., mean of 62.5) micrometers.
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0.027459954))  ;Add the number of droplets multiplied by the probability that droplets will be 75-100 (i.e., mean of 87.5) micrometers.
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0.027459954))  ;Add the number of droplets multiplied by the probability that droplets will be 100-125 (i.e., mean of 112.5) micrometers.
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0.009153318))  ;Add the number of droplets multiplied by the probability that droplets will be 125-150 (i.e., mean of 137.5) micrometers.
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0.022883295))  ;Add the number of droplets multiplied by the probability that droplets will be 150-200 (i.e., mean of 175) micrometers.
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0.009153318))  ;Add the number of droplets multiplied by the probability that droplets will be 200-250 (i.e., mean of 225) micrometers.
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0.013729977))  ;Add the number of droplets multiplied by the probability that droplets will be 250-500 (i.e., mean of 375) micrometers.
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0.00228833))  ;Add the number of droplets multiplied by the probability that droplets will be 500-1000 (i.e., mean of 750) micrometers.
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750)
        ]
        if(speak_dropletSizeDistr = "meanlog.1")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 1, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0.90221))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.09769))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 1.00E-04))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
         if(speak_dropletSizeDistr = "meanlog.2")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 2, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0.02034))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.58528))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0.38923))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.0051))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 5.00E-05))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
         if(speak_dropletSizeDistr = "meanlog.3")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 3, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.00099))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0.22496))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.49652))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0.21661))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0.05001))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.00979))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.00111))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 1.00E-05))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750)
         ]
         if(speak_dropletSizeDistr = "meanlog.4")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 4, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 3.00E-05))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.00327))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0.03485))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0.11234))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.23613))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.46714))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0.12405))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0.01939))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0.00232))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0.00048))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750)
         ]
         if(speak_dropletSizeDistr = "meanlog.5")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 5, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.00012))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.01131))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0.0818))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0.19145))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0.22957))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0.32449))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0.11992))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0.04132))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 2.00E-05))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ;
        ]
      ]
      if cough-or-not = 1 [
        if(cough_dropletSizeDistr = "chao")[ ; if the droplet size distribution will be defined by the Chao et al. (2009) paper
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0.091863517))  ;Add the number of droplets multiplied by the probability that droplets will be 2-4 (i.e., mean of 3) micrometers.
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.461942257))  ;Add the number of droplets multiplied by the probability that droplets will be 4-8 (i.e., mean of 6) micrometers.
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0.170603675))  ;Add the number of droplets multiplied by the probability that droplets will be 8-16 (i.e., mean of 12) micrometers.
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.073490814))  ;Add the number of droplets multiplied by the probability that droplets will be 16-24 (i.e., mean of 20) micrometers.
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0.036745407))  ;Add the number of droplets multiplied by the probability that droplets will be 24-32 (i.e., mean of 28) micrometers.
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0.015748031))  ;Add the number of droplets multiplied by the probability that droplets will be 32-40 (i.e., mean of 36) micrometers.
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.005249344))  ;Add the number of droplets multiplied by the probability that droplets will be 40-50 (i.e., mean of 45) micrometers.
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.023622047))  ;Add the number of droplets multiplied by the probability that droplets will be 50-75 (i.e., mean of 62.5) micrometers.
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0.01312336))  ;Add the number of droplets multiplied by the probability that droplets will be 75-100 (i.e., mean of 87.5) micrometers.
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0.026246719))  ;Add the number of droplets multiplied by the probability that droplets will be 100-125 (i.e., mean of 112.5) micrometers.
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0.018372703))  ;Add the number of droplets multiplied by the probability that droplets will be 125-150 (i.e., mean of 137.5) micrometers.
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0.015748031))  ;Add the number of droplets multiplied by the probability that droplets will be 150-200 (i.e., mean of 175) micrometers.
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0.01312336))  ;Add the number of droplets multiplied by the probability that droplets will be 200-250 (i.e., mean of 225) micrometers.
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0.023622047))  ;Add the number of droplets multiplied by the probability that droplets will be 250-500 (i.e., mean of 375) micrometers.
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0.010498688))  ;Add the number of droplets multiplied by the probability that droplets will be 500-1000 (i.e., mean of 750) micrometers.
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
         if(cough_dropletSizeDistr = "meanlog.1")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 1, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0.90221))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.09769))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 1.00E-04))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
         if(cough_dropletSizeDistr = "meanlog.2")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 2, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0.02034))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.58528))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0.38923))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.0051))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 5.00E-05))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
         if(cough_dropletSizeDistr = "meanlog.3")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 3, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0))  ;Add the number of droplets multiplied by the probability that droplets will have a mean diameter <= 3 micrometers.
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0.00099))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0.22496))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.49652))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0.21661))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0.05001))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.00979))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.00111))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 1.00E-05))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
         if(cough_dropletSizeDistr = "meanlog.4")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 4, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 3.00E-05))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0.00327))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0.03485))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0.11234))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.23613))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.46714))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0.12405))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0.01939))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0.00232))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0.00048))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 0))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
         if(cough_dropletSizeDistr = "meanlog.5")[ ; if the droplet size distribution will be defined by sampling from a lognormal distribution with meanlog droplet size of 5, sdlog of 0.3, and length of 1000000.
          set droplets_size3 (droplets_size3 + (dropletDistrNum * 0))
          set droplets_size6 (droplets_size6 + (dropletDistrNum * 0))
          set droplets_size12 (droplets_size12 + (dropletDistrNum * 0))
          set droplets_size20 (droplets_size20 + (dropletDistrNum * 0))
          set droplets_size28 (droplets_size28 + (dropletDistrNum * 0))
          set droplets_size36 (droplets_size36 + (dropletDistrNum * 0))
          set droplets_size45 (droplets_size45 + (dropletDistrNum * 0.00012))
          set droplets_size62.5 (droplets_size62.5 + (dropletDistrNum * 0.01131))
          set droplets_size87.5 (droplets_size87.5 + (dropletDistrNum * 0.0818))
          set droplets_size112.5 (droplets_size112.5 + (dropletDistrNum * 0.19145))
          set droplets_size137.5 (droplets_size137.5 + (dropletDistrNum * 0.22957))
          set droplets_size175 (droplets_size175 + (dropletDistrNum * 0.32449))
          set droplets_size225 (droplets_size225 + (dropletDistrNum * 0.11992))
          set droplets_size375 (droplets_size375 + (dropletDistrNum * 0.04132))
          set droplets_size750 (droplets_size750 + (dropletDistrNum * 2.00E-05))
          set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750) ; update the total droplet count
         ]
        ]
      ]
    ]
  ]
end

to remove-droplets   ;; Here we remove virions due to: inhalation by people, gravitational settling, and decay.
  ask patches with [(not wall?) and (not outdoor?) and (not furniture?) and (not counter?) and (total-droplets > 0)] [      ;; Here we remove virions in the aerosol due to: inhalation by people, gravitational settling, and decay. Note include all cells with air volumes!
    let inhaled-percent (vol-breathe / (1 * 1 * expectorate-height)) * (count customers-here)
    let size3-change (inhaled-percent + (1 / (expectorate-height / Vt_diam3 / 60)) + droplet-decay)   ;inhale + fall + decay percent
    if size3-change > 1 [set size3-change 1]   ;if > 1, set it 1
    let size6-change (inhaled-percent + (1 / (expectorate-height / Vt_diam6 / 60)) + droplet-decay)
    if size6-change > 1 [set size6-change 1]
    let size12-change (inhaled-percent + (1 / (expectorate-height / Vt_diam12 / 60)) + droplet-decay)
    if size12-change > 1 [set size12-change 1]
    let size20-change (inhaled-percent + (1 / (expectorate-height / Vt_diam20 / 60)) + droplet-decay)
    if size20-change > 1 [set size20-change 1]
    let size28-change (inhaled-percent + (1 / (expectorate-height / Vt_diam28 / 60)) + droplet-decay)
    if size28-change > 1 [set size28-change 1]
    let size36-change (inhaled-percent + (1 / (expectorate-height / Vt_diam36 / 60)) + droplet-decay)
    if size36-change > 1 [set size36-change 1]
    let size45-change (inhaled-percent + (1 / (expectorate-height / Vt_diam45 / 60)) + droplet-decay)
    if size45-change > 1 [set size45-change 1]
    let size62.5-change (inhaled-percent + (1 / (expectorate-height / Vt_diam62.5 / 60)) + droplet-decay)
    if size62.5-change > 1 [set size62.5-change 1]
    let size87.5-change (inhaled-percent + (1 / (expectorate-height / Vt_diam87.5 / 60)) + droplet-decay)
    if size87.5-change > 1 [set size87.5-change 1]
    let size112.5-change (inhaled-percent + (1 / (expectorate-height / Vt_diam112.5 / 60)) + droplet-decay)
    if size112.5-change > 1 [set size112.5-change 1]
    let size137.5-change (inhaled-percent + (1 / (expectorate-height / Vt_diam137.5 / 60)) + droplet-decay)
    if size137.5-change > 1 [set size137.5-change 1]
    let size175-change (inhaled-percent + (1 / (expectorate-height / Vt_diam175 / 60)) + droplet-decay)
    if size175-change > 1 [set size175-change 1]
    let size225-change (inhaled-percent + (1 / (expectorate-height / Vt_diam225 / 60)) + droplet-decay)
    if size225-change > 1 [set size225-change 1]
    let size375-change (inhaled-percent + (1 / (expectorate-height / Vt_diam375 / 60)) + droplet-decay)
    if size375-change > 1 [set size375-change 1]
    let size750-change (inhaled-percent + (1 / (expectorate-height / Vt_diam750 / 60)) + droplet-decay)
    if size750-change > 1 [set size750-change 1]

    set droplets_size3 droplets_size3 * (1 - size3-change)
    set droplets_size6 droplets_size6 * (1 - size6-change)
    set droplets_size12 droplets_size12 * (1 - size12-change)
    set droplets_size20 droplets_size20 * (1 - size20-change)
    set droplets_size28 droplets_size28 * (1 - size28-change)
    set droplets_size36 droplets_size36 * (1 - size36-change)
    set droplets_size45 droplets_size45 * (1 - size45-change)
    set droplets_size62.5 droplets_size62.5 * (1 - size62.5-change)
    set droplets_size87.5 droplets_size87.5 * (1 - size87.5-change)
    set droplets_size112.5 droplets_size112.5 * (1 - size112.5-change)
    set droplets_size137.5 droplets_size137.5 * (1 - size137.5-change)
    set droplets_size175 droplets_size175 * (1 - size175-change)
    set droplets_size225 droplets_size225 * (1 - size225-change)
    set droplets_size375 droplets_size375 * (1 - size375-change)
    set droplets_size750 droplets_size750 * (1 - size750-change)
  ]
  ask patches with [(furniture?) and (total-droplets > 0)] [    ;; Here we remove virions on the furniture/shelves due to decay. Assume furniture as plastic.
    set droplets_size3 droplets_size3 * (1 - plastic-decay)
    set droplets_size6 droplets_size6 * (1 - plastic-decay)
    set droplets_size12 droplets_size12 * (1 - plastic-decay)
    set droplets_size20 droplets_size20 * (1 - plastic-decay)
    set droplets_size28 droplets_size28 * (1 - plastic-decay)
    set droplets_size36 droplets_size36 * (1 - plastic-decay)
    set droplets_size45 droplets_size45 * (1 - plastic-decay)
    set droplets_size62.5 droplets_size62.5 * (1 - plastic-decay)
    set droplets_size87.5 droplets_size87.5 * (1 - plastic-decay)
    set droplets_size112.5 droplets_size112.5 * (1 - plastic-decay)
    set droplets_size137.5 droplets_size137.5 * (1 - plastic-decay)
    set droplets_size175 droplets_size175 * (1 - plastic-decay)
    set droplets_size225 droplets_size225 * (1 - plastic-decay)
    set droplets_size375 droplets_size375 * (1 - plastic-decay)
    set droplets_size750 droplets_size750 * (1 - plastic-decay)
  ]
  ask patches with [(counter?) and (total-droplets > 0)] [    ;; Here we remove virions on the counter due to decay. Assume counter as stainless steel.
    set droplets_size3 droplets_size3 * (1 - steel-decay)
    set droplets_size6 droplets_size6 * (1 - steel-decay)
    set droplets_size12 droplets_size12 * (1 - steel-decay)
    set droplets_size20 droplets_size20 * (1 - steel-decay)
    set droplets_size28 droplets_size28 * (1 - steel-decay)
    set droplets_size36 droplets_size36 * (1 - steel-decay)
    set droplets_size45 droplets_size45 * (1 - steel-decay)
    set droplets_size62.5 droplets_size62.5 * (1 - steel-decay)
    set droplets_size87.5 droplets_size87.5 * (1 - steel-decay)
    set droplets_size112.5 droplets_size112.5 * (1 - steel-decay)
    set droplets_size137.5 droplets_size137.5 * (1 - steel-decay)
    set droplets_size175 droplets_size175 * (1 - steel-decay)
    set droplets_size225 droplets_size225 * (1 - steel-decay)
    set droplets_size375 droplets_size375 * (1 - steel-decay)
    set droplets_size750 droplets_size750 * (1 - steel-decay)
  ]
end

to move-air    ;; Assume a simple-forced movement where air moves only towards the return vent(s) and return vents return number droplets * ventil_movementRate * (1 - ventil_removalRate) droplets to supply vents.
  ;for each patch, there are 1 removal (droplets go to the neighbored patch) and 1 adding (additional droplets from the neighbored patch) procedure.
  ; ventil-movement-rate ; Describes the proportion of droplets suspended in the air that will move to another patch (directed by location of return vent(s)) per hour!
  ; ventil-removal-rate ; Describes the proportion of droplets on return vent patch(es) that will be removed from the simulation due to filtration.
  ; num-air-patch * Volume per unit * ACH = num-return-vent * (ventil-movement-rate * Volume per unit) * (3600s /delta t)

  let num-air-patch count patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)]
  let num-return-vent count patches with [return-vent = true]
  set ventil-movement-rate (num-air-patch * ACH / (num-return-vent * (3600 / dt)))

  if count patches with [return-vent = true] > 0 [
    let droplet-size3-return-count (sum ([droplets_size3] of patches with [return-vent = true])) * (ventil-movement-rate)     ;determine the number of droplets that will be removed from returnVents; first sum, then * ventilation rate
    let droplet-size6-return-count (sum ([droplets_size6] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size12-return-count (sum ([droplets_size12] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size20-return-count (sum ([droplets_size20] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size28-return-count (sum ([droplets_size28] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size36-return-count (sum ([droplets_size36] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size45-return-count (sum ([droplets_size45] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size62.5-return-count (sum ([droplets_size62.5] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size87.5-return-count (sum ([droplets_size87.5] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size112.5-return-count (sum ([droplets_size112.5] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size137.5-return-count (sum ([droplets_size137.5] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size175-return-count (sum ([droplets_size175] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size225-return-count (sum ([droplets_size225] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size375-return-count (sum ([droplets_size375] of patches with [return-vent = true])) * (ventil-movement-rate)
    let droplet-size750-return-count (sum ([droplets_size750] of patches with [return-vent = true])) * (ventil-movement-rate)

    ask patches with [supply-vent = true] [    ;add droplets to (only) the supply vents from remove vents
      set additionalDroplets_size3 additionalDroplets_size3 + droplet-size3-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size6 additionalDroplets_size6 + droplet-size6-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size12 additionalDroplets_size12 + droplet-size12-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size20 additionalDroplets_size20 + droplet-size20-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size28 additionalDroplets_size28 + droplet-size28-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size36 additionalDroplets_size28 + droplet-size36-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size45 additionalDroplets_size45 + droplet-size45-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size62.5 additionalDroplets_size62.5 + droplet-size62.5-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size87.5 additionalDroplets_size87.5 + droplet-size87.5-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size112.5 additionalDroplets_size112.5 + droplet-size112.5-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size137.5 additionalDroplets_size137.5 + droplet-size137.5-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size175 additionalDroplets_size175 + droplet-size175-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size225 additionalDroplets_size225 + droplet-size225-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size375 additionalDroplets_size375 + droplet-size375-return-count * (1 - ventil-removal-rate) / num-supply-vent
      set additionalDroplets_size750 additionalDroplets_size750 + droplet-size750-return-count * (1 - ventil-removal-rate) / num-supply-vent
    ]

    ask airarrows [    ;; here we calculate droplets to patches due to air movement: obtain the droplets number moved-in from the source patch, namely "additional" (for all patches except the supply vents above)
      if [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] of patch-ahead 1 [    ; only move-air between patches with air volumes

      let droplet-size3-count [droplets_size3] of patch-here
      let droplet-size6-count [droplets_size6] of patch-here
      let droplet-size12-count [droplets_size12] of patch-here
      let droplet-size20-count [droplets_size20] of patch-here
      let droplet-size28-count [droplets_size28] of patch-here
      let droplet-size36-count [droplets_size36] of patch-here
      let droplet-size45-count [droplets_size45] of patch-here
      let droplet-size62.5-count [droplets_size62.5] of patch-here
      let droplet-size87.5-count [droplets_size87.5] of patch-here
      let droplet-size112.5-count [droplets_size112.5] of patch-here
      let droplet-size137.5-count [droplets_size137.5] of patch-here
      let droplet-size175-count [droplets_size175] of patch-here
      let droplet-size225-count [droplets_size225] of patch-here
      let droplet-size375-count [droplets_size375] of patch-here
      let droplet-size750-count [droplets_size750] of patch-here
      ask patch-ahead 1 [     ;add droplets to patch 1 meter ahead at the pre-determined rate
        set additionalDroplets_size3 additionalDroplets_size3 + droplet-size3-count * (ventil-movement-rate)     ; only give "additional droplets > 0" definition to patches with air volume
        set additionalDroplets_size6 additionalDroplets_size6 + droplet-size6-count * (ventil-movement-rate)
        set additionalDroplets_size12 additionalDroplets_size12 + droplet-size12-count * (ventil-movement-rate)
        set additionalDroplets_size20 additionalDroplets_size20 + droplet-size20-count * (ventil-movement-rate)
        set additionalDroplets_size28 additionalDroplets_size28 + droplet-size28-count * (ventil-movement-rate)
        set additionalDroplets_size36 additionalDroplets_size36 + droplet-size36-count * (ventil-movement-rate)
        set additionalDroplets_size45 additionalDroplets_size45 + droplet-size45-count * (ventil-movement-rate)
        set additionalDroplets_size62.5 additionalDroplets_size62.5 + droplet-size62.5-count * (ventil-movement-rate)
        set additionalDroplets_size87.5 additionalDroplets_size87.5 + droplet-size87.5-count * (ventil-movement-rate)
        set additionalDroplets_size112.5 additionalDroplets_size112.5 + droplet-size112.5-count * (ventil-movement-rate)
        set additionalDroplets_size137.5 additionalDroplets_size137.5 + droplet-size137.5-count * (ventil-movement-rate)
        set additionalDroplets_size175 additionalDroplets_size175 + droplet-size175-count * (ventil-movement-rate)
        set additionalDroplets_size225 additionalDroplets_size225 + droplet-size225-count * (ventil-movement-rate)
        set additionalDroplets_size375 additionalDroplets_size375 + droplet-size375-count * (ventil-movement-rate)
        set additionalDroplets_size750 additionalDroplets_size750 + droplet-size750-count * (ventil-movement-rate)
        ]
      ]
    ]

        ;Now that we've denoted how many droplets of each size to add to patches, we can remove them. Note that this had to be done with a separate ask because if we add and remove in the same step, droplet additions to patches assessed later in the cue will be erroneous.

   ask patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [           ; first, remove droplets gone to the patch ahead
        set droplets_size3 droplets_size3 * (1 - (ventil-movement-rate))
        set droplets_size6 droplets_size6 * (1 - (ventil-movement-rate))
        set droplets_size12 droplets_size12 * (1 - (ventil-movement-rate))
        set droplets_size20 droplets_size20 * (1 - (ventil-movement-rate))
        set droplets_size28 droplets_size28 * (1 - (ventil-movement-rate))
        set droplets_size36 droplets_size36 * (1 - (ventil-movement-rate))
        set droplets_size45 droplets_size45 * (1 - (ventil-movement-rate))
        set droplets_size62.5 droplets_size62.5 * (1 - (ventil-movement-rate))
        set droplets_size87.5 droplets_size87.5 * (1 - (ventil-movement-rate))
        set droplets_size112.5 droplets_size112.5 * (1 - (ventil-movement-rate))
        set droplets_size137.5 droplets_size137.5 * (1 - (ventil-movement-rate))
        set droplets_size175 droplets_size175 * (1 - (ventil-movement-rate))
        set droplets_size225 droplets_size225 * (1 - (ventil-movement-rate))
        set droplets_size375 droplets_size375 * (1 - (ventil-movement-rate))
        set droplets_size750 droplets_size750 * (1 - (ventil-movement-rate))
    ]

    ask patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [    ; second, add droplets moved-in from source patch. Note that this had to be done with a separate ask because if we add and remove in the same step, droplet additions to patches assessed later in the cue will be erroneous.
      set droplets_size3 droplets_size3 + additionalDroplets_size3   ;add the appropriate number of droplets of this size, only patches with air volume have "additional droplets > 0"
      set droplets_size6 droplets_size6 + additionalDroplets_size6
      set droplets_size12 droplets_size12 + additionalDroplets_size12
      set droplets_size20 droplets_size20 + additionalDroplets_size20
      set droplets_size28 droplets_size28 + additionalDroplets_size28
      set droplets_size36 droplets_size36 + additionalDroplets_size36
      set droplets_size45 droplets_size45 + additionalDroplets_size45
      set droplets_size62.5 droplets_size62.5 + additionalDroplets_size62.5
      set droplets_size87.5 droplets_size87.5 + additionalDroplets_size87.5
      set droplets_size112.5 droplets_size112.5 + additionalDroplets_size112.5
      set droplets_size137.5 droplets_size137.5 + additionalDroplets_size137.5
      set droplets_size175 droplets_size175 + additionalDroplets_size175
      set droplets_size225 droplets_size225 + additionalDroplets_size225
      set droplets_size375 droplets_size375 + additionalDroplets_size375
      set droplets_size750 droplets_size750 + additionalDroplets_size750

      set additionalDroplets_size3  0   ;reset the additional droplet counter
      set additionalDroplets_size6   0
      set additionalDroplets_size12  0
      set additionalDroplets_size20  0
      set additionalDroplets_size28  0
      set additionalDroplets_size36  0
      set additionalDroplets_size45  0
      set additionalDroplets_size62.5  0
      set additionalDroplets_size87.5  0
      set additionalDroplets_size112.5  0
      set additionalDroplets_size137.5  0
      set additionalDroplets_size175  0
      set additionalDroplets_size225  0
      set additionalDroplets_size375  0
      set additionalDroplets_size750 0
    ]
  ]
end

to diffuse-droplets      ;note the "diffusion-rate" differs from "ventil-movement-rate" in the forced air movement
  ask patches with [(not wall?) and (not outdoor?) and (not furniture?) and (not counter?)] [
    set additionalDroplets_size3  0  ; reset the additional droplet counter
    set additionalDroplets_size6   0
    set additionalDroplets_size12  0
    set additionalDroplets_size20  0
    set additionalDroplets_size28  0
    set additionalDroplets_size36  0
    set additionalDroplets_size45  0
    set additionalDroplets_size62.5  0
    set additionalDroplets_size87.5  0
    set additionalDroplets_size112.5  0
    set additionalDroplets_size137.5  0
    set additionalDroplets_size175  0
    set additionalDroplets_size225  0
    set additionalDroplets_size375  0
    set additionalDroplets_size750 0
  ]

  ask patches with [(not wall?) and (not outdoor?) and (not furniture?) and (not counter?)] [ ; counts to the additionalDroplet variables of neighbors
    let numNeighbors count neighbors with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)]   ; count the number of neighbors of a patch with air volume!
    let dropletSize3-diffusion-count (droplets_size3 * diffusion-rate)  ; the number of droplets of this size that will be removed from this patch due to diffusion.
    let dropletSize6-diffusion-count (droplets_size6 * diffusion-rate)
    let dropletSize12-diffusion-count (droplets_size12 * diffusion-rate)
    let dropletSize20-diffusion-count (droplets_size20 * diffusion-rate)
    let dropletSize28-diffusion-count (droplets_size28 * diffusion-rate)
    let dropletSize36-diffusion-count (droplets_size36 * diffusion-rate)
    let dropletSize45-diffusion-count (droplets_size45 * diffusion-rate)
    let dropletSize62.5-diffusion-count (droplets_size62.5 * diffusion-rate)
    let dropletSize87.5-diffusion-count (droplets_size87.5 * diffusion-rate)
    let dropletSize112.5-diffusion-count (droplets_size112.5 * diffusion-rate)
    let dropletSize137.5-diffusion-count (droplets_size137.5 * diffusion-rate)
    let dropletSize175-diffusion-count (droplets_size175 * diffusion-rate)
    let dropletSize225-diffusion-count (droplets_size225 * diffusion-rate)
    let dropletSize375-diffusion-count (droplets_size375 * diffusion-rate)
    let dropletSize750-diffusion-count (droplets_size750 * diffusion-rate)

    ask neighbors with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [      ;only give "additional droplets > 0" definition  to patches with air volume
      set additionalDroplets_size3  additionalDroplets_size3 + (dropletSize3-diffusion-count / numNeighbors)   ; obtain the number of droplets which is evenly distributed among neighbors, to be add later
      set additionalDroplets_size6  additionalDroplets_size6 + (dropletSize6-diffusion-count / numNeighbors)
      set additionalDroplets_size12 additionalDroplets_size12 + (dropletSize12-diffusion-count / numNeighbors)
      set additionalDroplets_size20 additionalDroplets_size20 + (dropletSize20-diffusion-count / numNeighbors)
      set additionalDroplets_size28 additionalDroplets_size28 + (dropletSize28-diffusion-count / numNeighbors)
      set additionalDroplets_size36 additionalDroplets_size36 + (dropletSize36-diffusion-count / numNeighbors)
      set additionalDroplets_size45 additionalDroplets_size45 + (dropletSize45-diffusion-count / numNeighbors)
      set additionalDroplets_size62.5 additionalDroplets_size62.5 + (dropletSize62.5-diffusion-count / numNeighbors)
      set additionalDroplets_size87.5 additionalDroplets_size87.5 + (dropletSize87.5-diffusion-count / numNeighbors)
      set additionalDroplets_size112.5 additionalDroplets_size112.5 + (dropletSize112.5-diffusion-count / numNeighbors)
      set additionalDroplets_size137.5 additionalDroplets_size137.5 + (dropletSize137.5-diffusion-count / numNeighbors)
      set additionalDroplets_size175 additionalDroplets_size175 + (dropletSize175-diffusion-count / numNeighbors)
      set additionalDroplets_size225 additionalDroplets_size225 + (dropletSize225-diffusion-count / numNeighbors)
      set additionalDroplets_size375 additionalDroplets_size375 + (dropletSize375-diffusion-count / numNeighbors)
      set additionalDroplets_size750 additionalDroplets_size750 + (dropletSize750-diffusion-count / numNeighbors)
    ]

    set droplets_size3 droplets_size3 - dropletSize3-diffusion-count ; first, remove droplets from the current patch
    set droplets_size6 droplets_size6 - dropletSize6-diffusion-count
    set droplets_size12 droplets_size12 - dropletSize12-diffusion-count
    set droplets_size20 droplets_size20 - dropletSize20-diffusion-count
    set droplets_size28 droplets_size28 - dropletSize28-diffusion-count
    set droplets_size36 droplets_size36 - dropletSize36-diffusion-count
    set droplets_size45 droplets_size45 - dropletSize45-diffusion-count
    set droplets_size62.5 droplets_size62.5 - dropletSize62.5-diffusion-count
    set droplets_size87.5 droplets_size87.5 - dropletSize87.5-diffusion-count
    set droplets_size112.5 droplets_size112.5 - dropletSize112.5-diffusion-count
    set droplets_size137.5 droplets_size137.5 - dropletSize137.5-diffusion-count
    set droplets_size175 droplets_size175 - dropletSize175-diffusion-count
    set droplets_size225 droplets_size225 - dropletSize225-diffusion-count
    set droplets_size375 droplets_size375 - dropletSize375-diffusion-count
    set droplets_size750 droplets_size750 - dropletSize750-diffusion-count
  ]

  ask patches with [(not wall?) and (not outdoor?) and (not furniture?) and (not counter?)] [
    set droplets_size3 droplets_size3 + additionalDroplets_size3 ; second, add the additional droplets (> 0) only to patches with air volume after removal.
    set droplets_size6 droplets_size6 + additionalDroplets_size6
    set droplets_size12 droplets_size12 + additionalDroplets_size12
    set droplets_size20 droplets_size20 + additionalDroplets_size20
    set droplets_size28 droplets_size28 + additionalDroplets_size28
    set droplets_size36 droplets_size36 + additionalDroplets_size36
    set droplets_size45 droplets_size45 + additionalDroplets_size45
    set droplets_size62.5 droplets_size62.5 + additionalDroplets_size62.5
    set droplets_size87.5 droplets_size87.5 + additionalDroplets_size87.5
    set droplets_size112.5 droplets_size112.5 + additionalDroplets_size112.5
    set droplets_size137.5 droplets_size137.5 + additionalDroplets_size137.5
    set droplets_size175 droplets_size175 + additionalDroplets_size175
    set droplets_size225 droplets_size225 + additionalDroplets_size225
    set droplets_size375 droplets_size375 + additionalDroplets_size375
    set droplets_size750 droplets_size750 + additionalDroplets_size750
  ]
end

to inhale
  ask patches with [total-droplets > 0] [     ;actually due to diffusion and low decay & ventilation rate ,almost the total-droplets of all patches > 0 (small-sizes)
    set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750)
    set virion-count (((1.40947E-14 * 1000 * virions-per-ml) * droplets_size3) + ((1.12758E-13 * 1000 * virions-per-ml) * droplets_size6) + ((9.02064E-13 * 1000 * virions-per-ml) * droplets_size12) + ((4.17622E-12 * 1000 * virions-per-ml) * droplets_size20) + ((1.14595E-11 * 1000 * virions-per-ml) * droplets_size28) + ((2.43557E-11 * 1000 * virions-per-ml) * droplets_size36) + ((4.75698E-11 * 1000 * virions-per-ml) * droplets_size45) + ((1.27448E-10 * 1000 * virions-per-ml) * droplets_size62.5) + ((3.49718E-10 * 1000 * virions-per-ml) * droplets_size87.5) + ((7.43277E-10 * 1000 * virions-per-ml) * droplets_size112.5) + ((1.35707E-09 * 1000 * virions-per-ml) * droplets_size137.5) + ((2.79774E-09 * 1000 * virions-per-ml) * droplets_size175) + ((5.94622E-09 * 1000 * virions-per-ml) * droplets_size225) + ((2.75288E-08 * 1000 * virions-per-ml) * droplets_size375) + ((2.2023E-07 * 1000 * virions-per-ml) * droplets_size750))

    ask customers-here [
      set timesteps_exposed timesteps_exposed + 1   ;count of the number of timesteps when an agent was exposed to total-droplets > 0.
      if infected? = false and infectious? = false [      ;only ask uninfected person
        ifelse mask? = true
        [set inhaled-virions inhaled-virions + (vol-breathe / (1 * 1 * expectorate-height)) * ([virion-count] of patch-here) * mask-effect-inhale]    ;record the inhaled accumulated virions for uninfected persons.
        [set inhaled-virions inhaled-virions + (vol-breathe / (1 * 1 * expectorate-height)) * ([virion-count] of patch-here)]
      ]
    ]
  ]
end

to surface-cleaning
  if surface-cleaning-interval > 0 [
    if times mod (surface-cleaning-interval * 60 / dt) = 0 [
      ask patches with [(furniture?) or (counter?)] [
        set droplets_size3 droplets_size3 * 0.001
        set droplets_size6 droplets_size6 * 0.001
        set droplets_size12 droplets_size12 * 0.001
        set droplets_size20 droplets_size20 * 0.001
        set droplets_size28 droplets_size28 * 0.001
        set droplets_size36 droplets_size36 * 0.001
        set droplets_size45 droplets_size45 * 0.001
        set droplets_size62.5 droplets_size62.5 * 0.001
        set droplets_size87.5 droplets_size87.5 * 0.001
        set droplets_size112.5 droplets_size112.5 * 0.001
        set droplets_size137.5 droplets_size137.5 * 0.001
        set droplets_size175 droplets_size175 * 0.001
        set droplets_size225 droplets_size225 * 0.001
        set droplets_size375 droplets_size375 * 0.001
        set droplets_size750 droplets_size750 * 0.001
      ]
    ]
  ]
end

to virus-transfer-hand-to-face
  ask customers [
    if infected? = false and infectious? = false [      ;only ask uninfected person
      ifelse mask? = true    ;the use of masks reduced the probability of facial mucosal membrane touch per min from 1.6 × 10-1 per min to 5.4 × 10-2 per min (face-touch-frequency / 3), because touches of the eyes accounted for 33% of the facial mucosal membrane touches involving the eyes, nose, and mouth.
      [set virions-to-facial-membranes virions-to-facial-membranes + (virions-on-hand * fingers-to-face-ratio * transfer-efficiency-hand-to-face * face-touch-frequency * mask-effect-touching)]    ;record the inhaled accumulated virions for uninfected persons.
      [set virions-to-facial-membranes virions-to-facial-membranes + (virions-on-hand * fingers-to-face-ratio * transfer-efficiency-hand-to-face * face-touch-frequency)]
    ]
  ]
end

to calculate-virions
  ask patches [
    set total-droplets (droplets_size3 + droplets_size6 + droplets_size12 + droplets_size20 + droplets_size28 + droplets_size36 + droplets_size45 + droplets_size62.5 + droplets_size87.5 + droplets_size112.5 + droplets_size137.5 + droplets_size175 + droplets_size225 + droplets_size375 + droplets_size750)
    set virion-count (((1.40947E-14 * 1000 * virions-per-ml) * droplets_size3) + ((1.12758E-13 * 1000 * virions-per-ml) * droplets_size6) + ((9.02064E-13 * 1000 * virions-per-ml) * droplets_size12) + ((4.17622E-12 * 1000 * virions-per-ml) * droplets_size20) + ((1.14595E-11 * 1000 * virions-per-ml) * droplets_size28) + ((2.43557E-11 * 1000 * virions-per-ml) * droplets_size36) + ((4.75698E-11 * 1000 * virions-per-ml) * droplets_size45) + ((1.27448E-10 * 1000 * virions-per-ml) * droplets_size62.5) + ((3.49718E-10 * 1000 * virions-per-ml) * droplets_size87.5) + ((7.43277E-10 * 1000 * virions-per-ml) * droplets_size112.5) + ((1.35707E-09 * 1000 * virions-per-ml) * droplets_size137.5) + ((2.79774E-09 * 1000 * virions-per-ml) * droplets_size175) + ((5.94622E-09 * 1000 * virions-per-ml) * droplets_size225) + ((2.75288E-08 * 1000 * virions-per-ml) * droplets_size375) + ((2.2023E-07 * 1000 * virions-per-ml) * droplets_size750))

  ]
  ask customers [
    set total-virions-exposed (inhaled-virions + virions-to-facial-membranes)
  ]
end

to-report dose-response [virions]    ;using Watanabe et al.'s model for SARS Coronavirus, and Zhang, Xiaole, et al.'s deduction through SARS-CoV-2 data.
  let dose (virions / 300)  ; about 300 viral genome copies were present per PFU, the unit in Watanabe et al.'s model is PFU (plaque-forming units)
  let p (1 - exp (- dose / k))   ;  p is the the infection risk, k is virions-related
  report p
end

to assess-distance  ; (instant)
  if count customers > 1 [
    let distance-list (list)
    ask customers [
      ask other customers [
        set distance-list lput (distance myself) distance-list
      ]
    ]
    set avg-distance mean distance-list
    set avg-distance precision avg-distance 2
  ]
end

to assess-close-contact-exposures  ; to assess the present number of close-contact-exposure
  if (any? customers with [infected? = true]) and (any? customers with [infectious? = false]) [    ; these 2 types need to exist, in case of error.
    let patches-in-cone-list (list)   ;Statistics patches-in-cone for all infected customers
    ask customers with [infectious?] [
      set patches-in-cone-list lput patches-in-cone patches-in-cone-list
    ]
    set customers-in-close-contact (count customers-on patch-set patches-in-cone-list)   ;patch-set to merge?
  ]
end

to assess-air-contamination-level      ; implant tracker "virion-count", to keep track of the risk of patches in the simulation
  if any? customers with [infected? = true] [
    let patch-virions-list (list)   ;create a temporary list
    ask patches with [(not wall?) and (not outdoor?) and (not furniture?) and (not counter?)] [      ; select patches with air volume
      set patch-virions-list lput virion-count patch-virions-list   ;ask each patch to add risk to it
    ]
    set avg-air-patch-virions mean patch-virions-list
    set avg-air-patch-virions precision avg-air-patch-virions 2
  ]
end

to assess-surface-contamination-level
  if any? customers with [infected? = true] [
    let patch-virions-list (list)   ;create a temporary list
    ask patches with [(furniture?) or (counter?)] [
      set patch-virions-list lput virion-count patch-virions-list   ;ask each patch to add risk to it
    ]
    set avg-surface-patch-virions mean patch-virions-list
    set avg-surface-patch-virions precision avg-surface-patch-virions 2
  ]
end

to assess-accumulated-inhaled-virions   ; (instant) assess the present condition
  if (any? customers with [infected? = true]) and (any? customers with [infectious? = false]) [    ; these 2 types need to exist, in case of error.
    let inhaled-virions-list (list)
    ask customers with [infectious? = false] [
      set inhaled-virions-list lput inhaled-virions inhaled-virions-list
    ]
    set avg-inhaled-virions mean inhaled-virions-list
    set avg-inhaled-virions precision avg-inhaled-virions 2
    set sum-inhaled-virions sum inhaled-virions-list
    set sum-inhaled-virions precision sum-inhaled-virions 2
  ]
end

to assess-accumulated-touched-virions   ; (instant) assess the present condition
  if (any? customers with [infected? = true]) and (any? customers with [infectious? = false]) [    ; these 2 types need to exist, in case of error.
    let touched-virions-list (list)
    ask customers with [infectious? = false] [
      set touched-virions-list lput virions-to-facial-membranes touched-virions-list
    ]
    set avg-touched-virions mean touched-virions-list
    set avg-touched-virions precision avg-touched-virions 2
    set sum-touched-virions sum touched-virions-list
    set sum-touched-virions precision sum-touched-virions 2
  ]
end

to assess-accumulated-total-virions   ; (instant) assess the present condition
  if (any? customers with [infected? = true]) and (any? customers with [infectious? = false]) [    ; these 2 types need to exist, in case of error.
    let total-virions-list (list)
    ask customers with [infectious? = false] [
      set total-virions-list lput total-virions-exposed total-virions-list
    ]
    set avg-total-virions mean total-virions-list
    set avg-total-virions precision avg-total-virions 2
    set sum-total-virions sum total-virions-list
    set sum-total-virions precision sum-total-virions 2
  ]
end

to assess-exposure-time-level    ; (accumulated) actually aerosols exist for a very long time, so near "always". the curves always go up due to accumlation of time. However, sometimes when in large spaces, maybe useful.
  if (any? customers with [infected? = true]) and (any? customers with [infectious? = false]) [    ; these 2 types need to exist, in case of error.
    let exposure-time-count-list (list)
    ask customers with [infectious? = false] [
      set exposure-time-count-list lput timesteps_exposed exposure-time-count-list
    ]
    set avg-exposure-time mean exposure-time-count-list
    set avg-exposure-time precision avg-exposure-time 2
  ]
end

to assess-infection-prob
  ;set total-virions-exposed (inhaled-virions + virions-to-facial-membranes)
  if vaccinated? = false [
    let infect-prob random-float 1    ;if examined every 0.05s (dt), it actually increases the infection probability (increasing the chances like lottery). Only when the customer leaves the supermarket, the total virus exposure statistics of the customer and the prediction of the infection probability are more meaningful. In fact, the dose-increasing-procedure may also affect the results.
      if infect-prob <= dose-response total-virions-exposed [
      set infected? true
      set color orange    ; orange indicates a person just infected (not infectious), to differ from the original infected and infectious person. Just a flash.
      set total-infected total-infected + 1    ; "implant tracker" to inspect and assess
    ]
  ]
  if total-infected = 1 [set first-infection-time ticks]
  set percentage-of-probable-infections (total-infected / (total-customers - total-infected - total-originally-infected))
  set percentage-of-probable-infections precision percentage-of-probable-infections 5
end

to record   ;using list to record
  set avg-distance-list lput avg-distance avg-distance-list
  set customers-in-close-contact-list lput customers-in-close-contact customers-in-close-contact-list  ;record the customers in cone for each tick-advance.
  set avg-air-contamination-list lput avg-air-patch-virions avg-air-contamination-list
  set avg-surface-contamination-list lput avg-surface-patch-virions avg-surface-contamination-list
  set avg-inhaled-virions-list lput avg-inhaled-virions avg-inhaled-virions-list
  set sum-inhaled-virions-list lput sum-inhaled-virions sum-inhaled-virions-list
  set avg-touched-virions-list lput avg-touched-virions avg-touched-virions-list
  set sum-touched-virions-list lput sum-touched-virions sum-touched-virions-list
  set avg-total-virions-list lput avg-total-virions avg-total-virions-list
  set sum-total-virions-list lput sum-total-virions sum-total-virions-list

  set total-infected-list lput total-infected total-infected-list
  set total-susceptible-list lput (total-customers - total-infected - total-originally-infected) total-susceptible-list
  set total-originally-infected-list lput total-originally-infected total-originally-infected-list
  set total-customers-list lput total-customers total-customers-list

  set percentage-of-probable-infections-list lput percentage-of-probable-infections percentage-of-probable-infections-list
  set tick-list lput ticks tick-list
  ;set time-list lput current_time time-list  ; recording time failed, for the list is always composed of the last "current-time"

  set avg-exposure-time-list lput avg-exposure-time avg-exposure-time-list

end

to recolor-patch   ;visualize the virus in the air (for each step)
  ask patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [
    ifelse (virion-count > 0)
    [let min-virion min [virion-count] of patches
     let max-virion max [virion-count] of patches
     set pcolor scale-color magenta virion-count 100000 min-virion] ; all contaminated patches will be a shade of pink. The darker the color, the more infectious the patch is.  "max-virion or 100000 (fixed)?"
    [set pcolor white]
  ]

  if [pcolor] of one-of patches with [wall?] != black [     ; in case of after pressing "showing paths/virions" button, recover the view
    ask patches with [wall?] [set pcolor black]
    ask patches with [outdoor?] [set pcolor 8]
    ask patches with [furniture?] [set pcolor 38]
    ask patches with [counter?] [set pcolor 36]
    ask patches with [(checkout-station?) and open-status = 1] [set plabel "open" set plabel-color 6]
    ask patches with [exit?] [set plabel "exit" set plabel-color 6]
    ask customers [st]
  ]
end

to display-labels-customers
  ask customers [
    set label ""
    set label-color blue - 2
  ]
  if show-customers-virions? [
    ask customers with [infectious? = false] [set label round inhaled-virions]
    ;ask customers with [infectious? = false] [set label who]     ; use who to check bugs
  ]
end

to display-labels-patches
  ask patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [
    set plabel ""
    set plabel-color blue
  ]
  if show-patches-virions? [
    ask patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [set plabel precision virion-count 2]
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Analysis ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to show-path    ;; "passed" is used to record the number of steps stayed (waited + walked) on this patch
  cd
  ask customers [ht]
  ask patches [set plabel ""]
  let sum_passed sum [passed] of patches
  ask patches [set heat-path passed / sum_passed]
  let min-heat min [heat-path] of patches
  let max-heat max [heat-path] of patches
  ask patches [set pcolor scale-color orange heat-path max-heat min-heat]

  ask patches with [furniture?] [set pcolor 38]  ;; set the entity as the defined color for better visulization
  ask patches with [counter?] [set pcolor 36]
  ask patches with [wall?] [set pcolor black]
  ask patches with [outdoor?] [set pcolor 8]
end

to show-virion
  cd
  ask customers [ht]
  ask patches [set plabel ""]
  let sum_virion-count sum [virion-count] of patches
  ask patches [set heat-virion-count virion-count / sum_virion-count]
  let min-heat min [heat-virion-count] of patches
  let max-heat max [heat-virion-count] of patches
  ask patches [set pcolor scale-color magenta heat-virion-count max-heat min-heat]    ;clear color steps, but not helpful to comparing!!
end

to show-virion-air
  cd
  ask customers [st]
  ask customers with [infectious? = false] [set label round inhaled-virions]
  ask patches [set plabel ""]

  ask patches with [(not wall?) and (not furniture?) and (not counter?) and (not outdoor?)] [
    ifelse (virion-count > 0)
    [let min-virion min [virion-count] of patches
     let max-virion max [virion-count] of patches
     set pcolor scale-color magenta virion-count 100000 0] ; all contaminated patches will be a shade of pink. The darker the color, the more infectious the patch is.
    [set pcolor white]
  ]

  ;let sum_virion-count sum [virion-count] of patches with [floor? or checkout-zone? or checkout-station? or entrance? or exit? or return-vent? or supply-vent?]
  ;ask patches with [floor? or checkout-zone? or checkout-station? or entrance? or exit?] [set heat-virion-count virion-count / sum_virion-count]
  ;let min-heat min [heat-virion-count] of patches
  ;let max-heat max [heat-virion-count] of patches
  ;ask patches with [floor? or checkout-zone? or checkout-station? or entrance? or exit? or return-vent? or supply-vent?] [set pcolor scale-color magenta heat-virion-count max-heat min-heat]

  ask patches with [furniture?] [set pcolor 38]  ;; set the entity as the defined color for better visulization
  ask patches with [counter?] [set pcolor 36]
  ask patches with [wall?] [set pcolor black]
  ask patches with [outdoor?] [set pcolor 8]
  ;ask patches with [return-vent?] [set pcolor 115]
  ;ask patches with [supply-vent?] [set pcolor 117]
end

to show-virion-surface
  cd
  ask customers [st]
  ask customers with [infectious? = false] [set label round inhaled-virions]
  ask patches [set plabel ""]

  ask patches with [furniture? or counter?] [
    set pcolor scale-color magenta virion-count 1000000000 0
  ]

  ;let sum_virion-count sum [virion-count] of patches with [furniture? or counter?]
  ;ask patches with [furniture? or counter?] [set heat-virion-count virion-count / sum_virion-count]
  ;let min-heat min [heat-virion-count] of patches
  ;let max-heat max [heat-virion-count] of patches
  ;ask patches with [furniture? or counter?] [set pcolor scale-color magenta heat-virion-count max-heat min-heat]    ;clear color steps, but not helpful to comparing!!

  ask patches with [(not furniture?) and (not counter?)] [set pcolor 4]   ; set the background gray for better visualization
  ask patches with [wall?] [set pcolor black]
  ask patches with [outdoor?] [set pcolor 8]
  ;ask patches with [return-vent?] [set pcolor 115]
  ;ask patches with [supply-vent?] [set pcolor 117]
end

;to show-transmission-risk
  ;cd
  ;ask customers [ht]
  ;ask patches [set plabel ""]
  ;let sum_transmission-risk sum [transmission-risk] of patches
  ;ask patches [set heat-transmission-risk transmission-risk / sum_transmission-risk]
  ;let min-heat min [heat-transmission-risk] of patches
  ;let max-heat max [heat-transmission-risk] of patches
  ;ask patches [set pcolor scale-color magenta heat-transmission-risk max-heat min-heat]    ;clear color steps, but not helpful to comparing!!

  ;ask patches [
    ;ifelse transmission-risk > 0
    ;[set pcolor scale-color magenta (transmission-risk * (vol-breathe / (1 * 1 * expectorate-height))) 0.99 0]     ; not very clear for very heavy patches, need to determine the range more precisely.
    ;[set pcolor white]
  ;]
;end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Data Output ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to export-csv
  let original-output-list (list tick-list avg-distance-list customers-in-close-contact-list avg-air-contamination-list avg-surface-contamination-list avg-inhaled-virions-list sum-inhaled-virions-list avg-touched-virions-list sum-touched-virions-list avg-total-virions-list sum-total-virions-list total-infected-list total-susceptible-list total-originally-infected-list total-customers-list percentage-of-probable-infections-list)
  let matrix-list matrix:from-column-list original-output-list
  let output-list matrix:to-row-list matrix-list
  csv:to-file word user-input "file name?" "-list.csv" output-list
end

to export-main-indexes    ;one thing to keep in mind is that csv:to-file expects a "list of lists", so if you want to export a list (just one row), wrap it in another list!
  csv:to-file word user-input "file name?" "-main-index.csv" (list (list (mean avg-distance-list) (sum customers-in-close-contact-list) (mean avg-air-contamination-list) (mean avg-surface-contamination-list) (max avg-surface-contamination-list) (sum sum-inhaled-virions-list) (sum sum-touched-virions-list) (sum sum-total-virions-list) (total-infected) (total-customers - total-infected - total-originally-infected) (total-originally-infected) (total-customers) (mean percentage-of-probable-infections-list) (first-infection-time)))
end

to export-all
  let name user-input "file name?"

  let original-output-list (list tick-list avg-distance-list customers-in-close-contact-list avg-air-contamination-list avg-surface-contamination-list avg-inhaled-virions-list sum-inhaled-virions-list avg-touched-virions-list sum-touched-virions-list avg-total-virions-list sum-total-virions-list total-infected-list total-susceptible-list total-originally-infected-list total-customers-list percentage-of-probable-infections-list)
  let matrix-list matrix:from-column-list original-output-list
  let output-list matrix:to-row-list matrix-list
  csv:to-file word name "-list.csv" output-list

  csv:to-file word name "-main-index.csv" (list (list (mean avg-distance-list) (sum customers-in-close-contact-list) (mean avg-air-contamination-list) (mean avg-surface-contamination-list) (max avg-surface-contamination-list) (sum sum-inhaled-virions-list) (sum sum-touched-virions-list) (sum sum-total-virions-list) (total-infected) (total-customers - total-infected - total-originally-infected) (total-originally-infected) (Total-customers) (mean percentage-of-probable-infections-list) (first-infection-time)))
  export-all-plots word name "-all-plots.csv"
  export-world word name "-world.csv"
  export-interface word name "-interface.jpg"
  export-view word name "-view.jpg"
end

to format-csv
  let input-file user-file
  let original-output-list csv:from-file input-file
  let matrix-list matrix:from-column-list original-output-list
  let output-list matrix:to-row-list matrix-list
  csv:to-file word user-input "file name?" "-list-transpose.csv" output-list
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Check speed ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to profile
  profiler:start
  repeat 10 [go]
  profiler:stop
  print profiler:report
  profiler:reset
end
@#$#@#$#@
GRAPHICS-WINDOW
1140
10
1628
614
-1
-1
16.552
1
10
1
1
1
0
0
0
1
0
28
0
35
1
1
1
ticks
50.0

BUTTON
205
165
365
198
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
205
55
290
88
Draw
draw-env
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
15
55
95
88
Import Image
ca\nset file-name user-file\nifelse file-name = false [stop]\n[import-pcolors file-name\n\nask patches [if pcolor mod 10 > 9 [set pcolor white]]\nask patches with [ 92 < pcolor and pcolor < 97] [set pcolor blue]\nask patches with [ 82 < pcolor and pcolor < 87] [set pcolor cyan]\n\nask patches with [ 42 < pcolor and pcolor < 47] [set pcolor yellow]\nask patches with [ pcolor = 9] [set pcolor 9]\nask patches with [ 12 < pcolor and pcolor < 17] [set pcolor red]\nask patches with [ 52 < pcolor and pcolor < 57] [set pcolor green]\nask patches with [ 22 < pcolor and pcolor < 27] [set pcolor orange]\nask patches with [ pcolor = 114] [set pcolor 114]\nask patches with [ pcolor = 117] [set pcolor 117]\nask patches with [ pcolor = 8] [set pcolor 8]\nask patches with [ pcolor = 36] [set pcolor 36]\nask patches with [ pcolor = 39] [set pcolor 39]\npatch-color\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
290
55
365
88
Clear All
;; (for this model to work with NetLogo's new plotting features,\n  ;; __clear-all-and-reset-ticks should be replaced with clear-all at\n  ;; the beginning of your setup procedure and reset-ticks at the end\n  ;; of the procedure.)\n  clear-all\n  reset-ticks
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
95
90
175
123
Export World
export-world word user-input \"file name?\" \".csv\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
15
90
95
123
Import World
set file-name user-file\nifelse file-name = false [stop][import-world file-name]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
205
150
360
176
Setting Environment!
12
0.0
1

TEXTBOX
205
40
340
58
Edit Environment
12
0.0
1

TEXTBOX
779
40
894
58
Simulation Time
12
0.0
1

TEXTBOX
970
195
1075
221
Make a Movie
12
0.0
1

TEXTBOX
585
35
600
775
_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_
12
0.0
1

TEXTBOX
395
535
575
561
Walking (social force model)
11
0.0
1

TEXTBOX
395
40
545
58
Customers
12
0.0
1

TEXTBOX
10
10
80
31
⊙ File
18
0.0
1

TEXTBOX
200
10
350
30
⊙ Environment
18
0.0
1

TEXTBOX
395
10
545
30
⊙ Agents
18
0.0
1

BUTTON
15
130
175
163
Import SHP
clear-all\nshp-import
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
205
90
365
135
draw-elements
draw-elements
"Wall(black)" "Entrance(Yellow)" "CheckOutZone(gray9)" "CheckOutStation(red)" "Exit(Cyan)" "Furniture(38)" "Counter(36)" "InaccessibleArea(39)" "Window(Blue)" "ReturnVent(115)" "SupplyVent(117)" "Outdoor(8)" "Erase(white)"
11

SLIDER
779
56
929
89
Simulation_hours
Simulation_hours
0.1
24
8.0
0.1
1
NIL
HORIZONTAL

TEXTBOX
15
40
155
58
Import/Export
12
0.0
1

TEXTBOX
774
10
924
28
⊙ Simulation
18
0.0
1

TEXTBOX
185
35
200
705
_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_
12
0.0
1

TEXTBOX
759
36
774
696
_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_
12
0.0
1

BUTTON
95
55
175
88
Export Image
export-view word user-input \"file name?\" \".png\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
779
96
919
114
Show footprint
12
0.0
1

TEXTBOX
970
10
1070
30
⊙ Analysis
18
0.0
1

TEXTBOX
944
36
959
701
_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_
12
0.0
1

BUTTON
970
56
1070
89
NIL
show-path
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
395
585
540
618
V0
V0
0
5
1.29
0.1
1
NIL
HORIZONTAL

SLIDER
395
620
540
653
Tr
Tr
0.1
2
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
395
655
540
688
A
A
0
5
2.0
0.1
1
NIL
HORIZONTAL

SLIDER
395
690
540
723
D
D
0.1
5
0.5
0.1
1
NIL
HORIZONTAL

CHOOSER
779
111
929
156
show_track
show_track
"Do not show" "Show tracks"
0

SLIDER
395
549
540
582
dt
dt
0
1
0.25
0.01
1
NIL
HORIZONTAL

MONITOR
1365
640
1420
685
NIL
ticks
17
1
11

MONITOR
1140
640
1365
685
NIL
current_time
17
1
11

BUTTON
855
290
930
323
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
780
290
855
323
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
395
56
555
89
max-customer-number
max-customer-number
1
800
50.0
1
1
NIL
HORIZONTAL

SLIDER
395
91
556
124
enter-interval
enter-interval
0
600
5.0
1
1
s
HORIZONTAL

SLIDER
396
182
556
215
max-length-shopping-list
max-length-shopping-list
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
396
218
556
251
max-prob-for-change
max-prob-for-change
0
99
10.0
1
1
%
HORIZONTAL

TEXTBOX
396
168
531
186
Shopping list
12
0.0
1

TEXTBOX
395
725
545
765
Recommeded:\ndt 0.05 V0 1.29 m/s Tr 0.5 A 2.0 D 0.5 m
12
0.0
1

SLIDER
205
225
365
258
percent-checkout-open
percent-checkout-open
0
100
50.0
1
1
%
HORIZONTAL

TEXTBOX
205
210
290
228
Checkout
12
0.0
1

MONITOR
1430
640
1520
685
Checkout open
count patches with [checkout-station? and open-status = 1]
17
1
11

MONITOR
1520
640
1630
685
Checkout closed
count patches with [checkout-station? and (open-status = 0 or open-status = 3)]
17
1
11

SLIDER
205
260
365
293
avg-checkout-speed
avg-checkout-speed
0.1
3
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
395
126
555
159
customer-patience
customer-patience
0
100
50.0
1
1
%
HORIZONTAL

BUTTON
970
210
1070
243
NIL
make-movie
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
780
276
835
294
Run!
12
0.0
1

TEXTBOX
595
10
725
30
⊙ Droplets
18
0.0
1

CHOOSER
600
55
750
100
speak_dropletSizeDistr
speak_dropletSizeDistr
"chao" "meanlog.1" "meanlog.2" "meanlog.3" "meanlog.4" "meanlog.5"
0

CHOOSER
600
105
750
150
cough_dropletSizeDistr
cough_dropletSizeDistr
"chao" "meanlog.1" "meanlog.2" "meanlog.3" "meanlog.4" "meanlog.5"
0

TEXTBOX
600
39
770
66
Droplet size distribution
12
0.0
1

SWITCH
205
325
365
358
ventilation
ventilation
0
1
-1000

TEXTBOX
205
310
365
328
Simple-forced ventilation
12
0.0
1

TEXTBOX
375
35
390
775
_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_
12
0.0
1

TEXTBOX
970
40
1015
58
Paths
12
0.0
1

SLIDER
205
460
365
493
ACH
ACH
0
50
5.0
0.01
1
NIL
HORIZONTAL

SLIDER
205
515
365
548
ventil-removal-rate
ventil-removal-rate
0
1
0.4
0.01
1
NIL
HORIZONTAL

TEXTBOX
205
430
355
466
Percent indoor air replacement / hour(ACH)
12
0.0
1

SWITCH
205
385
365
418
show-arrows
show-arrows
0
1
-1000

SLIDER
396
271
556
304
Infected-percentage
Infected-percentage
0
1
0.05
0.01
1
NIL
HORIZONTAL

TEXTBOX
396
255
546
273
Infected percentage
12
0.0
1

SLIDER
396
327
556
360
symptomatic-percentage
symptomatic-percentage
0
1
0.8
0.01
1
NIL
HORIZONTAL

TEXTBOX
396
310
546
328
Symptomatic percentage
12
0.0
1

TEXTBOX
2480
10
2890
330
Model outputs: \n\navg distance: Average interpersonal distance at a given tick.\n\ncustomers in close contact: The number of customers in cone of  infectious people at each tick.\naccumulated exposure of person * times: Accumulated exposure instances of person * times in cone of infectious people in the store.\n\navg air contamination level: The mean virions level of the indoor air environment at each tick.\n\navg surface contamination level: The mean virions level of the indoor surfaces at each tick.\n\navg inhaled virions: Average inhaled virions at a given tick.\n\navg touched virions: Average touched virions at a given tick.\n\nPrediction of infection.\n\nfirst-infection-time: Time (i.e., tick-advance) at which the first successful transmission event occurs. \n\n\n\n\n\n\n\n\n\n
12
0.0
1

TEXTBOX
972
98
1025
116
Virions
12
0.0
1

SWITCH
780
181
930
214
show-customers-virions?
show-customers-virions?
0
1
-1000

TEXTBOX
780
166
917
184
Show virions
12
0.0
1

TEXTBOX
205
500
355
518
Filter efficiency
12
0.0
1

TEXTBOX
205
370
355
388
Show air flow direction
12
0.0
1

MONITOR
1680
760
2070
805
first-infection-time
first-infection-time
17
1
11

TEXTBOX
1140
625
1165
643
Time
12
0.0
1

TEXTBOX
1430
625
1580
643
Checkout status
12
0.0
1

TEXTBOX
1682
556
1872
582
Infection risk prediction
12
0.0
1

MONITOR
2070
574
2195
619
NIL
total-infected
17
1
11

MONITOR
2070
710
2195
755
NIL
Total-customers
17
1
11

MONITOR
2070
664
2195
709
NIL
total-originally-infected
17
1
11

MONITOR
2070
620
2195
665
total-susceptible
total-customers - total-infected - total-originally-infected
17
1
11

PLOT
1680
574
2070
754
infection status (in total)
time
customer number
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"infected" 1.0 0 -955883 true "" "plot total-infected"
"susceptible" 1.0 0 -7500403 true "" "plot (total-customers - total-infected - total-originally-infected)"
"originally infected" 1.0 0 -2674135 true "" "plot total-originally-infected"
"total" 1.0 0 -16777216 true "" "plot total-customers"

PLOT
1680
190
1935
335
avg air contamination level
time
average virions number
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-air-patch-virions"

PLOT
1678
26
1933
166
avg distance
time
avg distance
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"avg distance" 1.0 0 -16777216 true "" "plot avg-distance"

PLOT
1938
26
2193
166
customers in close contact
time
close contact 
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"customers in close contact" 1.0 0 -16777216 true "" "plot customers-in-close-contact"

TEXTBOX
1678
176
1828
194
Environmental monitoring
12
0.0
1

TEXTBOX
1680
350
1825
376
Customers' exposure
12
0.0
1

PLOT
1680
365
1935
505
sum inhaled virions level
time
avg inhaled virions
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"sum inhaled virions" 1.0 0 -16777216 true "" "plot sum-inhaled-virions"

MONITOR
2088
49
2183
94
accumulated exposure of person * times
sum customers-in-close-contact-list
17
1
11

TEXTBOX
2945
-14
3095
4
Not using now
12
0.0
1

TEXTBOX
2919
-10
2934
665
_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_\n_
12
0.0
1

TEXTBOX
1680
6
1915
32
Spatial distribution of customers
12
0.0
1

BUTTON
970
270
1100
303
export list
export-csv
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
970
255
1080
273
Export data
12
0.0
1

BUTTON
970
150
1100
183
NIL
show-virion-surface
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
970
115
1100
148
NIL
show-virion-air
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
2040
190
2295
335
avg surface contamination level
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-surface-patch-virions"

PLOT
1940
365
2195
505
sum touched virions level
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum-touched-virions"

PLOT
2202
366
2447
506
sum total exposed virions level
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum-total-virions"

SLIDER
396
491
556
524
queueing-distance
queueing-distance
0
2
0.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
396
476
581
502
Social distance while queueing
11
0.0
1

SLIDER
396
381
556
414
mask-percentage
mask-percentage
0
1
0.0
0.01
1
NIL
HORIZONTAL

TEXTBOX
396
367
546
385
Mask percentage
12
0.0
1

SLIDER
396
437
556
470
vaccinated-percentage
vaccinated-percentage
0
1
0.0
0.01
1
NIL
HORIZONTAL

TEXTBOX
396
421
546
439
Vaccinated percentage
12
0.0
1

SLIDER
205
590
365
623
surface-cleaning-interval
surface-cleaning-interval
0
480
0.0
1
1
NIL
HORIZONTAL

TEXTBOX
205
560
325
586
Surface cleaning interval (min)
12
0.0
1

BUTTON
970
340
1100
373
export all plots
export-all-plots word user-input \"file name?\" \"-all-plots.csv\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
970
420
1050
438
Export JPG
12
0.0
1

BUTTON
970
375
1100
408
export world
export-world word user-input \"file name?\" \"-world.csv\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
970
470
1100
503
export world-view
export-view word user-input \"file name?\" \"-view.jpg\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
970
435
1100
468
export interface
export-interface word user-input \"file name?\" \"-interface.jpg\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1860
100
1920
145
NIL
mean avg-distance-list
3
1
11

MONITOR
1940
190
2025
235
NIL
mean avg-air-contamination-list
2
1
11

MONITOR
2300
190
2410
235
NIL
mean avg-surface-contamination-list
2
1
11

MONITOR
2300
235
2410
280
NIL
max avg-surface-contamination-list
2
1
11

BUTTON
970
305
1100
338
export main indexes
export-main-indexes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1825
510
1935
555
accumulated avg inhaled virions
sum avg-inhaled-virions-list
2
1
11

MONITOR
2090
510
2195
555
accumulated touched virions
sum sum-touched-virions-list
2
1
11

MONITOR
2340
510
2450
555
accumulated total virions
sum avg-total-virions-list
2
1
11

MONITOR
1940
235
2025
280
NIL
max avg-air-contamination-list
2
1
11

BUTTON
970
545
1100
578
export all
export-all
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
970
515
1100
541
Export all (One-click export!)
12
0.0
1

MONITOR
2455
575
2610
620
Percentage of probable infections
percentage-of-probable-infections
4
1
11

PLOT
2200
575
2450
755
percentage of probable infections
NIL
NIL
0.0
10.0
0.0
0.02
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot percentage-of-probable-infections"

MONITOR
2455
665
2610
710
max
max percentage-of-probable-infections-list
4
1
11

MONITOR
2455
710
2610
755
min
min percentage-of-probable-infections-list
4
1
11

MONITOR
2455
620
2610
665
mean
mean percentage-of-probable-infections-list
4
1
11

SWITCH
780
220
930
253
show-patches-virions?
show-patches-virions?
1
1
-1000

TEXTBOX
10
195
100
213
⊙ Test
18
0.0
1

BUTTON
15
230
175
263
NIL
set-customers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
265
175
298
customer-number
customer-number
0
30
2.0
1
1
NIL
HORIZONTAL

BUTTON
15
360
100
393
NIL
static-test
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
15
300
175
333
NIL
manual-move-customers
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
970
590
1100
623
NIL
format-csv
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)


Model feature:

1. activity-based model 2. social force model 3. explicit droplets distribution when speaking/coughing 4.simple-forced ventilation 5. dose-response diagnose

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
false
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

apple
false
0
Polygon -7500403 true true 33 58 0 150 30 240 105 285 135 285 150 270 165 285 195 285 255 255 300 150 268 62 226 43 194 36 148 32 105 35
Line -16777216 false 106 55 151 62
Line -16777216 false 157 62 209 57
Polygon -6459832 true false 152 62 158 62 160 46 156 30 147 18 132 26 142 35 148 46
Polygon -16777216 false false 132 25 144 38 147 48 151 62 158 63 159 47 155 30 147 18

arrow
false
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

arrow1
true
0
Line -7500403 true 150 15 105 75
Line -7500403 true 150 15 195 75

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
false
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
false
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

camera
false
0
Rectangle -7500403 true true 90 105 210 270
Polygon -7500403 true true 135 105 105 30 195 30 165 105 135 105

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

die 1
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 129 129 42

die 2
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 69 69 42
Circle -16777216 true false 189 189 42

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

head
true
0
Polygon -7500403 false true 180 75 105 75 60 90 15 135 15 165 60 210 105 225 180 225 195 225 240 210 285 165 285 135 240 90 195 75 180 75
Circle -7500403 true true 83 83 134
Line -7500403 true 150 120 150 30

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
false
0
Line -7500403 true 150 0 150 300

line half
false
0
Line -7500403 true 150 0 150 150

link
false
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rectangle
true
0
Rectangle -7500403 false true 0 0 300 300

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tile brick
false
0
Rectangle -1 true false 0 0 300 300
Rectangle -7500403 true true 15 225 150 285
Rectangle -7500403 true true 165 225 300 285
Rectangle -7500403 true true 75 150 210 210
Rectangle -7500403 true true 0 150 60 210
Rectangle -7500403 true true 225 150 300 210
Rectangle -7500403 true true 165 75 300 135
Rectangle -7500403 true true 15 75 150 135
Rectangle -7500403 true true 0 0 60 60
Rectangle -7500403 true true 225 0 300 60
Rectangle -7500403 true true 75 0 210 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
