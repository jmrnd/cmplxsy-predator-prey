globals [
  max-zebras ; don't let the zebra population grow too large
]

; zebra and lions are both breeds of turtles
breed [ zebras zebra ]
breed [ lions lion ]

turtles-own [ energy ]       ; both lions and zebra have energy

patches-own [
  countdown
  can-grow-grass?
]

lions-own [
  lion-speed
  detection-outer-radius
  detection-inner-radius
  pounce-duration-cd
  stalking-mode?
]

zebras-own [
  flockmates         ;; agentset of nearby turtles
  nearest-neighbor   ;; closest one of our flockmates
]

to setup
  clear-all
  ifelse netlogo-web? [ set max-zebras 10000 ] [ set max-zebras 30000 ]

  ; Initialize grass patches based on probability
  ask patches [
    ifelse random-float 100 < grass-spawn-probability [
      set pcolor green
      set countdown grass-regrowth-time
      set can-grow-grass? true
    ] [
      set pcolor brown
      set can-grow-grass? false
    ]
  ]

  create-zebras initial-number-zebras
  [
    set shape "zebra_prey"
    set color white
    set size 3
    set label-color blue - 2
    set energy random (3 * zebra-gain-from-food)
    setxy random-xcor random-ycor
  ]

  create-lions initial-number-lions
  [
    set shape "lionpredator"
    set color black
    set size 3
    set energy random (2 * lion-gain-from-food)
    setxy random-xcor random-ycor
    set lion-speed 1
    set detection-outer-radius 5
    set detection-inner-radius 3
    set pounce-duration-cd 0
    set stalking-mode? false
  ]

  display-labels
  reset-ticks
end


to go
  ; stop the model if there are no lions and no zebra
;  if not any? zebras [ stop ]
;  if not any? lions [ stop ]
  if ticks = 20000 [ stop ]
  ; stop the model if there are no lions and the number of zebra gets very large
  if not any? lions and count zebras > max-zebras [ user-message "The zebra have inherited the earth" stop ]

  ask zebras [
    flock
    zebra-move
    set energy energy - 1  ; deduct energy for zebra only if running zebra-lions-grass model version
    eat-grass  ; zebra eat grass only if running the zebra-lions-grass model version
    death ; zebra die from starvation only if running the zebra-lions-grass model version
    reproduce-zebra  ; zebra reproduce at a random rate governed by a slider
  ]

  ask lions [
    lion-move
    set energy energy - 1  ; lions lose energy as they move
    hunt-zebra ; LIONS CHECK FOR ZEBRAS WITHIN RANGE TO STALK
    death ; lions die if they run out of energy
    reproduce-lions ; lions reproduce at a random rate governed by a slider
  ]

  ask patches [
    if can-grow-grass? [
      grow-grass
    ]
  ]

  tick
  display-labels
end

to zebra-move  ; zebra procedure
  rt random 50
  lt random 50
  if not can-move? 1 [ rt 180 ]
  fd 1
end

to lion-move ; lion procedure
  rt random 45
  lt random 45
  if not can-move? 1 [ rt 180 ]
  fd lion-speed
end

to eat-grass  ; zebra procedure
  ; zebra eat grass and turn the patch brown
  if pcolor = green [
    set pcolor brown
    set energy energy + zebra-gain-from-food  ; zebra gain energy by eating
  ]
end

to reproduce-zebra  ; zebra procedure
  if random-float 100 < zebra-reproduce [  ; throw "dice" to see if you will reproduce
    set energy (energy / 2)                ; divide energy between parent and offspring
    hatch 1 [ rt random-float 360 fd 1 ]   ; hatch an offspring and move it forward 1 step
  ]
end

to reproduce-lions  ; lion procedure
  if random-float 100 < lion-reproduce [  ; throw "dice" to see if you will reproduce
    set energy (energy / 2)               ; divide energy between parent and offspring
    hatch 1 [ rt random-float 360 fd 1 ]  ; hatch an offspring and move it forward 1 step
  ]
end

to hunt-zebra ; lion procedure
  ifelse not stalking-mode? [
    set color black
    let nearby-zebra turtles in-radius detection-outer-radius with [ breed = zebras ]
    if any? nearby-zebra [
      set stalking-mode? true
      slow-down ; ENTER STALKING MODE
    ]
  ] [
    set color red
    let close-zebra turtles in-radius detection-inner-radius with [ breed = zebras ]
    if any? close-zebra [
      pounce ; INITIATE POUNCE
      set stalking-mode? false ; RESET STALKING MODE
      set lion-speed 1 ; RESET SPEED
    ]
  ]
end

to slow-down ; lion procedure
  set lion-speed 0.4
end

to pounce ; lion procedure
  let target-zebra one-of turtles in-radius detection-inner-radius with [ breed = zebras ]
  ifelse pounce-duration-cd = 0 [
    if target-zebra != nobody [
      face target-zebra
      fd detection-inner-radius
      ask target-zebra [ die ]
      set energy energy + lion-gain-from-food
      set pounce-duration-cd pounce-cd
    ]
  ] [
    set pounce-duration-cd pounce-duration-cd - 1
  ]
end

to death  ; turtle procedure (i.e. both lion and zebra procedure)
  ; when energy dips below zero, die
  if energy < 0 [ die ]
end

to grow-grass  ; patch procedure
  ; countdown on brown patches: if you reach 0, grow some grass
  if pcolor = brown [
    ifelse countdown <= 0 [
      set pcolor green
      set countdown grass-regrowth-time
    ] [
      set countdown countdown - 1
    ]
  ]
end

to-report grass
    report patches with [pcolor = green]
end


to display-labels
  ask turtles [ set label "" ]
  if show-energy? [
    ask lions [
      set label round energy
    ]

    ask zebras [
      set label round energy
    ]
  ]
end

;------------------------------------- FLOCKING START -----------------------------------------------

to flock  ;; turtle procedure
  find-flockmates
  if any? flockmates
    [ find-nearest-neighbor
      ifelse distance nearest-neighbor < minimum-separation
        [ separate ]
        [ align
          cohere ] ]
end

to find-flockmates  ;; turtle procedure
  set flockmates other turtles in-radius vision
end

to find-nearest-neighbor ;; turtle procedure
  set nearest-neighbor min-one-of flockmates [distance myself]
end

;;; SEPARATE

to separate  ;; turtle procedure
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end

;;; ALIGN

to align  ;; turtle procedure
  turn-towards average-flockmate-heading max-align-turn
end

to-report average-flockmate-heading  ;; turtle procedure
  ;; We can't just average the heading variables here.
  ;; For example, the average of 1 and 359 should be 0,
  ;; not 180.  So we have to use trigonometry.
  let x-component sum [dx] of flockmates
  let y-component sum [dy] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

;;; COHERE

to cohere  ;; turtle procedure
  turn-towards average-heading-towards-flockmates max-cohere-turn
end

to-report average-heading-towards-flockmates  ;; turtle procedure
  ;; "towards myself" gives us the heading from the other turtle
  ;; to me, but we want the heading from me to the other turtle,
  ;; so we add 180
  let x-component mean [sin (towards myself + 180)] of flockmates
  let y-component mean [cos (towards myself + 180)] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

;;; HELPER PROCEDURES

to turn-towards [new-heading max-turn]  ;; turtle procedure
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-away [new-heading max-turn]  ;; turtle procedure
  turn-at-most (subtract-headings heading new-heading) max-turn
end

;; turn right by "turn" degrees (or left if "turn" is negative),
;; but never turn more than "max-turn" degrees
to turn-at-most [turn max-turn]  ;; turtle procedure
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end
;------------------------------------- FLOCKING END -----------------------------------------------
@#$#@#$#@
GRAPHICS-WINDOW
385
15
945
576
-1
-1
10.824
1
14
1
1
1
0
0
0
1
-25
25
-25
25
1
1
1
ticks
30.0

SLIDER
10
15
200
48
initial-number-zebras
initial-number-zebras
0
250
60.0
1
1
NIL
HORIZONTAL

SLIDER
10
220
200
253
zebra-gain-from-food
zebra-gain-from-food
0.0
50.0
5.0
1.0
1
NIL
HORIZONTAL

SLIDER
10
260
200
293
zebra-reproduce
zebra-reproduce
1.0
20.0
3.0
1.0
1
%
HORIZONTAL

SLIDER
205
15
375
48
initial-number-lions
initial-number-lions
0
250
15.0
1
1
NIL
HORIZONTAL

SLIDER
205
220
375
253
lion-gain-from-food
lion-gain-from-food
0.0
100.0
70.0
1.0
1
NIL
HORIZONTAL

SLIDER
205
260
375
293
lion-reproduce
lion-reproduce
0.0
20.0
2.0
1.0
1
%
HORIZONTAL

SLIDER
10
60
200
93
grass-regrowth-time
grass-regrowth-time
0
100
50.0
1
1
NIL
HORIZONTAL

BUTTON
50
135
119
168
setup
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
125
135
200
168
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
960
75
1301
316
populations
time
pop.
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"grass / 4" 1.0 0 -10899396 true "" "plot count grass / 4"
"zebras" 1.0 0 -408670 true "" "plot count zebras"
"lions" 1.0 0 -16777216 true "" "plot count lions"

MONITOR
957
16
1024
61
zebras
count zebras
3
1
11

MONITOR
1030
15
1097
60
lions
count lions
3
1
11

MONITOR
1105
15
1170
60
grass
count grass / 4
0
1
11

TEXTBOX
20
190
160
208
Zebra settings
12
0.0
0

TEXTBOX
205
195
318
213
Lion settings
12
0.0
0

SWITCH
205
135
335
168
show-energy?
show-energy?
0
1
-1000

SLIDER
15
375
200
408
vision
vision
0.0
10.0
7.5
0.5
1
patches
HORIZONTAL

SLIDER
205
375
375
408
minimum-separation
minimum-separation
0.0
5.0
1.25
0.25
1
patches
HORIZONTAL

SLIDER
15
415
200
448
max-align-turn
max-align-turn
0.0
20.0
10.5
0.25
1
degrees
HORIZONTAL

SLIDER
205
415
375
448
max-cohere-turn
max-cohere-turn
0.0
20.0
10.0
0.25
1
degrees
HORIZONTAL

SLIDER
15
455
200
488
max-separate-turn
max-separate-turn
0.0
20.0
10.25
0.25
1
degrees
HORIZONTAL

SLIDER
205
300
375
333
pounce-cd
pounce-cd
0
20
15.0
1
1
NIL
HORIZONTAL

TEXTBOX
24
348
369
379
Zebra Flocking settings\n
12
0.0
1

SLIDER
205
60
375
93
grass-spawn-probability
grass-spawn-probability
0
100
70.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
# Predator-Prey Ecosystem

### CMPLXSY S11 Group 2
### Group Members
- HIDALGO, FRANCISCO
- IMPERIAL, IZABELLA
- MIRANDA, JAMAR
- SARMIENTO, RAFAEL

## Lion-Zebra Model

### General Environment
- Agents have energy
- Movement costs energy
- Losing all energy will result into death
- Agents reproduce asexually on a certain probability
- Grass patches are spawned randomly on the environment

### Lions
- Looks for Zebras to hunt and gain energy
- Lions reproduce asexually on a certain probability
- Lions move independently or in small groups
- Lions stalk their prey before chasing them
- Lions would pounce on their target if they are within a certain range

### Zebras
- Zebras look for grass patches to eat
- Zebras regain energy when they eat grass
- Zebras move in herds, staying close to each other for safety
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

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
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

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
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

lionpredator
false
3
Polygon -1184463 true false 45 90 30 105 15 120 15 135 30 150 45 165 60 150 75 135 90 105 90 90 90 75 60 75 45 90
Polygon -1184463 true false 135 90 135 90 180 105 210 105 240 120 240 120 255 135 270 120 255 105 255 90 285 120 270 135 255 150 255 150 240 165 225 180 210 195 225 210 210 240 180 240 195 225 180 195 180 180 180 180 165 180 150 180 120 180 105 195 105 210 90 240 60 240 75 225 75 210 75 180 105 150 120 120 120 105 135 90
Polygon -6459832 true true 255 90 255 105 225 90 240 90 255 90
Polygon -1184463 true false 255 165 270 195 270 210 270 225 270 240 240 240 255 225 255 210 225 180 240 165 255 150 255 150
Line -16777216 false 240 165 225 180
Line -16777216 false 255 150 240 165
Polygon -1184463 true false 105 210 120 225 135 225 150 210 135 210 120 195 120 180 105 195 105 210
Line -16777216 false 120 180 105 195
Line -16777216 false 105 195 105 210
Polygon -16777216 true false 15 120 15 120 30 120 15 135 15 135 15 120 30 135
Rectangle -1 true false 60 90 75 105
Polygon -6459832 true true 45 60 30 75 30 90 45 90 75 75 90 75 90 90 90 105 75 135 60 150 45 165 45 180 60 195 75 210 75 195 90 180 105 165 120 135 135 120 135 105 135 75 105 45 90 45 75 45 60 45 45 60 45 60
Polygon -16777216 true false 60 90 45 105 60 105 60 90
Line -16777216 false 30 150 45 150

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

zebra_prey
false
0
Polygon -1 true false 195 180 210 210 210 240 195 270 210 270 225 255 225 225 225 210 210 180 195 180
Polygon -1 true false 60 75 75 75 120 105 180 105 240 105 255 120 255 120 285 210 270 210 255 150 240 195 255 210 255 255 240 270 225 270 240 240 240 225 210 195 210 180 195 180 165 180 135 195 120 240 120 270 90 270 105 255 105 210 105 195 105 195 90 180 75 165 60 150 45 150 30 165 15 165 0 150 15 120 30 105 60 75 60 75
Polygon -16777216 true false 45 105 45 120 30 120 45 105
Polygon -16777216 true false 0 150 45 150 30 165 15 165 0 150 0 135 30 150
Polygon -16777216 true false 30 90 45 90 60 75 105 105 135 105 120 90 105 75 90 60 75 45 60 45 60 45 45 45 45 45 15 75 30 90 45 90 30 105
Polygon -1 true false 60 60 75 75 60 75 60 75
Polygon -1 true false 75 60 90 90 90 75 75 75 75 60
Polygon -1 true false 90 75 90 90 90 90 90 90 90 75
Polygon -1 true false 45 60 60 75 60 90 45 75
Polygon -16777216 true false 60 120 45 150 45 150 60 120 45 135 45 150
Polygon -16777216 true false 60 135 75 165 60 150 60 135 90 60 60 150
Polygon -16777216 true false 75 135 75 150 90 180 75 135 90 90 75 150
Polygon -16777216 true false 90 135 90 90 105 195 105 135 105 105 90 180
Polygon -1 true false 90 75 105 105 120 105 90 90 90 75
Polygon -16777216 true false 105 135 135 195 105 120 135 105 120 105 120 120
Polygon -16777216 true false 135 135 150 105 135 165 135 105 150 105 135 120
Polygon -16777216 true false 165 105 165 105 165 180 150 120 165 105 150 135
Polygon -16777216 true false 105 195 135 210 150 210 120 210 105 195
Polygon -16777216 true false 105 210 105 210 120 225 120 240 105 210
Polygon -16777216 true false 105 165 120 195 135 210 120 180 105 165 105 150
Polygon -16777216 true false 180 180 180 105 180 180 180 105 180 105 165 180
Polygon -16777216 true false 120 120 150 195 120 150 120 165 135 165 120 165
Polygon -16777216 true false 210 105 210 180 195 180 225 135 195 105 195 120
Polygon -16777216 true false 90 270 105 270 105 255 90 270 105 270
Polygon -16777216 true false 225 270 240 270 240 240 225 270 240 270
Polygon -16777216 true false 195 180 195 105 195 180 195 105 195 105 180 105
Polygon -16777216 true false 225 165 210 180 225 210 240 105 225 105 240 150
Polygon -16777216 true false 240 195 225 210 255 135 240 105 255 120 240 150
Polygon -16777216 true false 105 255 105 255 120 270 105 240 105 255
Polygon -16777216 true false 240 240 240 240 255 255 240 225 240 240
Polygon -16777216 true false 225 210 255 225 240 225 240 225 225 210
Polygon -16777216 true false 270 195 270 210 285 225 285 210 270 195
Polygon -1 true false 150 180 135 225 150 270 135 270 120 240 135 195 150 180
Line -16777216 false 135 195 135 195
Polygon -16777216 true false 120 240 135 270 150 270 135 255
Polygon -16777216 true false 210 225 225 225 225 240 225 240 210 225
Polygon -16777216 true false 195 180 210 210 225 210 225 210 210 195
Polygon -16777216 true false 195 270 225 270 210 270 210 255 210 240
Polygon -1 true false 30 60 30 105 30 90 30 105 45 75 30 60
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
set model-version "sheep-wolves-grass"
set show-energy? false
setup
repeat 75 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="New BehaviorSpace Features" repetitions="3" runMetricsEveryStep="false">
    <preExperiment>reset-timer</preExperiment>
    <setup>setup</setup>
    <go>go</go>
    <postExperiment>show timer</postExperiment>
    <timeLimit steps="200"/>
    <metric>count sheep</metric>
    <metric>count wolves</metric>
    <metric>[ xcor ] of sheep</metric>
    <metric>[ ycor ] of sheep</metric>
    <metric>[ xcor ] of wolves</metric>
    <metric>[ ycor ] of wolves</metric>
    <runMetricsCondition>ticks mod 2 = 0</runMetricsCondition>
    <subExperiment>
      <steppedValueSet variable="wolf-gain-from-food" first="30" step="5" last="50"/>
    </subExperiment>
  </experiment>
  <experiment name="BehaviorSpace run 3 experiments" repetitions="1" runMetricsEveryStep="false">
    <setup>setup
print (word "sheep-reproduce: " sheep-reproduce ", wolf-reproduce: " wolf-reproduce)
print (word "sheep-gain-from-food: " sheep-gain-from-food ", wolf-gain-from-food: " wolf-gain-from-food)</setup>
    <go>go</go>
    <postRun>print (word "sheep: " count sheep ", wolves: " count wolves)
print ""
wait 1</postRun>
    <timeLimit steps="1500"/>
    <metric>count sheep</metric>
    <metric>count wolves</metric>
    <metric>count grass</metric>
    <runMetricsCondition>ticks mod 10 = 0</runMetricsCondition>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;sheep-wolves-grass&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="sheep-reproduce">
        <value value="1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="sheep-gain-from-food">
        <value value="1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-reproduce">
        <value value="2"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-gain-from-food">
        <value value="10"/>
      </enumeratedValueSet>
    </subExperiment>
    <subExperiment>
      <enumeratedValueSet variable="sheep-reproduce">
        <value value="6"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="sheep-gain-from-food">
        <value value="8"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-reproduce">
        <value value="5"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-gain-from-food">
        <value value="20"/>
      </enumeratedValueSet>
    </subExperiment>
    <subExperiment>
      <enumeratedValueSet variable="sheep-reproduce">
        <value value="20"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="sheep-gain-from-food">
        <value value="15"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-reproduce">
        <value value="15"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-gain-from-food">
        <value value="30"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="BehaviorSpace run 3 variable values per experiments" repetitions="1" runMetricsEveryStep="false">
    <setup>setup
print (word "sheep-reproduce: " sheep-reproduce ", wolf-reproduce: " wolf-reproduce)
print (word "sheep-gain-from-food: " sheep-gain-from-food ", wolf-gain-from-food: " wolf-gain-from-food)</setup>
    <go>go</go>
    <postRun>print (word "sheep: " count sheep ", wolves: " count wolves)
print ""
wait 1</postRun>
    <timeLimit steps="1500"/>
    <metric>count sheep</metric>
    <metric>count wolves</metric>
    <metric>count grass</metric>
    <runMetricsCondition>ticks mod 10 = 0</runMetricsCondition>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;sheep-wolves-grass&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="sheep-reproduce">
        <value value="1"/>
        <value value="6"/>
        <value value="20"/>
      </enumeratedValueSet>
    </subExperiment>
    <subExperiment>
      <enumeratedValueSet variable="wolf-reproduce">
        <value value="2"/>
        <value value="7"/>
        <value value="15"/>
      </enumeratedValueSet>
    </subExperiment>
    <subExperiment>
      <enumeratedValueSet variable="sheep-gain-from-food">
        <value value="1"/>
        <value value="8"/>
        <value value="15"/>
      </enumeratedValueSet>
    </subExperiment>
    <subExperiment>
      <enumeratedValueSet variable="wolf-gain-from-food">
        <value value="10"/>
        <value value="20"/>
        <value value="30"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="BehaviorSpace subset" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>wait .5</postRun>
    <timeLimit steps="1500"/>
    <metric>count sheep</metric>
    <metric>count wolves</metric>
    <metric>count grass</metric>
    <runMetricsCondition>ticks mod 10 = 0</runMetricsCondition>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;sheep-wolves-grass&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="wolf-reproduce">
        <value value="3"/>
        <value value="5"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-gain-from-food">
        <value value="30"/>
        <value value="40"/>
      </enumeratedValueSet>
    </subExperiment>
    <subExperiment>
      <enumeratedValueSet variable="wolf-reproduce">
        <value value="10"/>
        <value value="15"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="wolf-gain-from-food">
        <value value="10"/>
        <value value="15"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="BehaviorSpace combinatorial" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>wait .5</postRun>
    <timeLimit steps="1500"/>
    <metric>count sheep</metric>
    <metric>count wolves</metric>
    <metric>count grass</metric>
    <runMetricsCondition>ticks mod 10 = 0</runMetricsCondition>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;sheep-wolves-grass&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce">
      <value value="3"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-food">
      <value value="10"/>
      <value value="15"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wolf Sheep Crossing" repetitions="4" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1500"/>
    <metric>count sheep</metric>
    <metric>count wolves</metric>
    <runMetricsCondition>count sheep = count wolves</runMetricsCondition>
    <enumeratedValueSet variable="wolf-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-energy?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-wolves">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-sheep">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;sheep-wolves-grass&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce">
      <value value="4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="New BehaviorSpace Features reproducible" repetitions="3" runMetricsEveryStep="false">
    <preExperiment>reset-timer</preExperiment>
    <setup>random-seed (474 + behaviorspace-run-number)

setup</setup>
    <go>go</go>
    <postExperiment>show timer</postExperiment>
    <timeLimit steps="200"/>
    <metric>count sheep</metric>
    <metric>count wolves</metric>
    <metric>[ xcor ] of sheep</metric>
    <metric>[ ycor ] of sheep</metric>
    <metric>[ xcor ] of wolves</metric>
    <metric>[ ycor ] of wolves</metric>
    <runMetricsCondition>ticks mod 2 = 0</runMetricsCondition>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;sheep-wolves-grass&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-energy?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-wolves">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-number-sheep">
      <value value="100"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="wolf-gain-from-food">
        <value value="10"/>
        <value value="20"/>
        <value value="30"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
</experiments>
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
