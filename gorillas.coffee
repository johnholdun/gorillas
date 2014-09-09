canvases = []
contexts = []
contextIndex = 0

colors =
  sky: [0, 0, 173]
  wind: [255, 0, 0]
  gorilla: [255, 170, 82]

sprites = {}
stage = {}

isWind = (color) ->
  color[0] >= 200 and color[1] < 50 and color[2] < 50

isSky = (color) ->
  color[0] < 50 and color[1] < 50 and color[2] >= 140

drawSprite = (context, sprite, xOffset, yOffset) ->
  context.drawImage sprite, xOffset, yOffset, sprite.width, sprite.height

drawCircle = (context, cx, cy, radius, color) ->
  return unless radius > 0
  cx = Math.round(cx)
  cy = Math.round(cy)
  width = radius * 2
  height = radius * 2
  x = cx - radius
  y = cy - radius

  data = context.getImageData x, y, width, height

  _.each _.range(0, width), (px) ->
    _.each _.range(0, height), (py) ->
      if Math.sqrt((radius - px) ** 2 + (radius - py) ** 2) <= radius
        pixelOffset = (py * width + px) * 4
        data.data[pixelOffset    ] = color[0]
        data.data[pixelOffset + 1] = color[1]
        data.data[pixelOffset + 2] = color[2]
        data.data[pixelOffset + 3] = 255

  context.putImageData data, x, y

leftGorilla = {
  side: 0,
  spriteNames: ["gorilla", "gorilla-left", "gorilla-right"]
  reset: ->
    @throwFrame = null
    @celebrating = false
    @celebrateFrame = null
    @dead = false
    return @

  place: (building) ->
    sprite = sprites[@spriteNames[0]]
    @width = sprite.width
    @height = sprite.height
    @x = building.left + Math.round((building.width - @width) / 2)
    @y = building.bottom - building.height - @height + 1

    @left = @x
    @right = @x + @width
    @top = @y
    @bottom = @y + @height

  draw: (context, frame) ->
    building = stage.buildings[@buildingIndex]
    sprite = sprites.gorilla

    if @throwFrame and frame - @throwFrame < 5
      sprite = sprites[["gorilla-left", "gorilla-right"][@side]]

    if @celebrating and frame - @celebrateFrame < 100
      spriteFrame = ["gorilla-right", "gorilla-left"][Math.floor((frame - @celebrateFrame) / 25) % 2]
      sprite = sprites[spriteFrame]
    else
      @celebrating = false

    drawSprite context,
      sprite,
      @x,
      @y

  throw: (frame, angle, velocity) ->
    @throwFrame = frame - 1
    banana.shoot frame,
      if @side == 1 then 180 - angle else angle,
      velocity
      @x + (@width - sprites["banana-up"].width) * @side,
      @y - 15

  celebrate: (frame) ->
    @celebrating = true
    @celebrateFrame = frame
}

rightGorilla = _.extend {}, leftGorilla, { side: 1 }

craters = {
  init: ->
    @canvas = document.createElement "canvas"
    @canvas.setAttribute "width", sprites.city.width
    @canvas.setAttribute "height", sprites.city.height
    @context = @canvas.getContext "2d"
    @members = []

  add: (frame, x, y, radius) ->
    crater = frame: frame, x: x, y: y, radius: radius

    drawCircle @context, x, y, radius, colors.sky

    @members.push crater

  collide: (x, y, width, height) ->
    region = @context.getImageData(x, y, width, height).data
    pixelParts = region.length / (width * height)
    result = _.find _.range(0, width * height), (pixel) ->
      color = [region[pixel * pixelParts], region[pixel * pixelParts + 1], region[pixel * pixelParts + 2]] 
      isSky color

    _.isNumber result

  exploding: (frame) ->
    pause = 10
    _.find @members, (crater) ->
      crater.frame + crater.radius + pause > frame

  draw: (context, frame) ->
    context.drawImage @canvas, 0, 0, @canvas.width, @canvas.height

    exploder = @exploding(frame)
    if exploder
      drawCircle context, exploder.x, exploder.y, exploder.radius - (frame - exploder.frame), [255, 0, 0]
}

banana = {
  spriteNames: ["banana-down", "banana-left", "banana-up", "banana-right"]
  draw: (context, frame) ->
    if @present
      t = (frame - @frameOffset) / 20
      @x = @origin.x + Math.round(@velocity.x * t)
      @y = @origin.y - Math.round((@velocity.y * t) + (0.5 * -9.8 * t ** 2))

      if @x < 0 or @x > context.canvas.width or @y > context.canvas.height
        @present = false
      else
        left = @x
        right = @x + @width
        top = @y
        bottom = @y + @height

        sunCollide = bottom > sun.top and top < sun.bottom and right > sun.left and left < sun.right

        if sunCollide
          sun.state = "shocked"

        playerCollide = (frame - @frameOffset > 10) and _.find [leftGorilla, rightGorilla], (gorilla) ->
          bottom > gorilla.top and top < gorilla.bottom and right > gorilla.left and left < gorilla.right

        if playerCollide
          [leftGorilla, rightGorilla][playerCollide.side].dead = true
          [leftGorilla, rightGorilla][1 - playerCollide.side].celebrate frame
          craters.add frame, @x, @y, 30
          @present = false

        else
          buildingCollide = _.find stage.buildings, (building) ->
            bLeft = building.left
            bRight = building.left + building.width
            bBottom = building.bottom
            bTop = building.bottom - building.height

            bottom > bTop and top < bBottom and right > bLeft and left < bRight

          if buildingCollide and !craters.collide @x, @y, @width, @height
            craters.add frame, @x, @y, 12
            @present = false

          else
            sprite = sprites[@spriteNames[Math.floor((frame - @frameOffset) / 3) % @spriteNames.length]]

      if @present
        drawSprite context, sprite, @x, @y

  shoot: (frame, angle, velocity, x, y) ->
    @width = sprites[@spriteNames[0]].width
    @height = sprites[@spriteNames[0]].height

    @velocity = {
      x: Math.cos(deg2rad(angle)) * velocity # + stage.wind
      y: Math.sin(deg2rad(angle)) * velocity
    }

    @frameOffset = frame
    @origin = { x: x, y: y }
    @present = true
}

sun = {
  spriteNames: ["sun", "sun-shocked"]
  place: (x, y) ->
    @x = x
    @y = y

    sprite = sprites[@spriteNames[0]]
    @width = sprite.width
    @height = sprite.height

    @left = @x
    @right = @x + @width
    @top = @y
    @bottom = @y + @height
  draw: (context, frame) ->
    sprite = sprites[@spriteNames[if @state == "shocked" then 1 else 0]]
    drawSprite context, sprite, @x, @y
}

draw = (frame) ->
  context = contexts[contextIndex]
  canvas = context.canvas
  canvas.className = "buffer"
  # canvas.style.border = "10px solid red"

  drawSprite context, sprites.city, 0, 0

  if frame > 0 && (leftGorilla.dead and !rightGorilla.celebrating) or (rightGorilla.dead and !leftGorilla.celebrating)
    startRound stage.round + 1

  else
    unless banana.present or craters.exploding(frame) or leftGorilla.celebrating or rightGorilla.celebrating
      sun.state = "relaxed"
      stage.turnCount++
      stage.turn = (stage.turn + 1) % 2
      shot = guessShot stage.turn, context
      [leftGorilla, rightGorilla][stage.turn].throw frame, shot.angle, shot.velocity

  leftGorilla.draw context, frame
  rightGorilla.draw context, frame

  craters.draw context, frame
  banana.draw context, frame
  sun.draw context, frame

  present = document.querySelector("canvas.present")
  canvas.className = "present"
  if present
    present.className = "buffer"
  # canvas.style.border = "none"
  contextIndex = (contextIndex + 1) % 2
  frame

readCity = ->
  image = sprites.city
  canvas = document.createElement "canvas"
  canvas.setAttribute "width", image.width
  canvas.setAttribute "height", image.height
  context = canvas.getContext "2d"
  context.drawImage image, 0, 0
  imageData = context.getImageData(0, 0, canvas.width, canvas.height)
  cityData = imageData.data
  pixelParts = imageData.data.length / (imageData.width * imageData.height)

  pixels = new Array(cityData.length / pixelParts / imageData.width);
  _.each _.range(0, canvas.height), (y) ->
    row = new Array(canvas.width)
    _.each _.range(0, canvas.width), (x) ->
      pixelIndex = (y * canvas.width + x) * pixelParts
      row[x] = [cityData[pixelIndex], cityData[pixelIndex + 1], cityData[pixelIndex + 2]]
    pixels[y] = row

  {
    width: imageData.width
    height: imageData.height
    pixels: pixels
  }

readWind = (city) ->
  wind = { x: {}, y: {} }
  _.each _.range(0, city.height), (y) ->
    _.each _.range(0, city.width), (x) ->
      if isWind city.pixels[y][x]
        wind.y[y] || wind.y[y] = 0
        wind.y[y]++ 
        wind.x[x] || wind.x[x] = 0
        wind.x[x]++

  windVal = ((_.max _.values wind.y) - 1) / 3
  # direction: the most commonly occurring x-value
  windDir = _.first _.last _.sortBy _.pairs(wind.x), 1
  windDir = if windDir > city.width / 2 then 1 else -1
  windVal *= windDir

  windVal /= 10

  windVal

readBuildings = (city) ->
  buildings = []

  x = 10
  inBuilding = false
  bottomBuilding = 0
  _.every _.range(0, city.height), (y) ->
    if isSky city.pixels[y][x]
      if inBuilding
        bottomBuilding = y - 1
        return false
    else
      inBuilding = true
    true

  inBuilding = false
  building = false
  _.each _.range(0, city.width), (x) ->
    if isSky city.pixels[bottomBuilding][x]
      if building
        building.width = x - building.left
        buildings.push building
        building = false

    else if !building
      building = { left: x, bottom: bottomBuilding }

  _.each buildings, (building) ->
    _.every _.range(bottomBuilding, 0, -1), (y) ->
      if isSky city.pixels[y][building.left]
        building.height = bottomBuilding - y
        return false
      true

  buildings

startRound = (round, cityId) ->
  sprites.city = if cityId
    sprites["city-" + cityId]
  else
    _.sample _.filter sprites, (sprite, id) ->
      id.match(/^city-/) and (!sprites.city or id != sprites.city.id)

  if stage and stage.interval
    clearInterval stage.interval

  cityData = readCity()
  stage =
    wind: readWind cityData
    buildings: readBuildings cityData
    turn: stage.turn || -1
    turnCount: -1
    round: round

  craters.init()

  leftGorilla.reset().place stage.buildings[_.random(1, 2)]
  rightGorilla.reset().place stage.buildings[stage.buildings.length - 1 - _.random(1, 2)]

  sun.state = "relaxed"
  sun.place 300, 10

  frame = 0

  window.next = ->
    { wtf: "Wtf" }
  if location.search.match "mode=manual"
    window.next = ->
      draw frame++
      return stage

  else
    stage.interval = setInterval ->
      draw frame++
    , 1000 / 30

guessShot = (turn, context) ->
  tosser = [leftGorilla, rightGorilla][turn]
  tossee = [leftGorilla, rightGorilla][1 - turn]

  origin = {
    x: if turn then tosser.right else tosser.left,
    y: tosser.top
  }

  destination = {
    x: Math.round(tossee.left + tossee.width / 2),
    y: Math.round(tossee.top + tossee.height / 2)
  }

  delta = {
    x: Math.abs(destination.x - origin.x),
    y: destination.y - origin.y
  }

  velocity = {}

  angle = 50 + _.random(0, 20)

  velocity = Math.sqrt(delta.x * 9.8 / Math.sin(2 * deg2rad(angle)))

  velocity = velocity - 10 + _.random(0, 20)
  velocity -= stage.wind * _.random 0.4, 0.7, 0.1

  { angle: angle, velocity: velocity }

deg2rad = (deg) ->
  deg / 180 * Math.PI

rad2deg = (rad) ->
  rad * 180 / Math.PI

window.init = init = init = ->
  return if window.initialized
  window.initialized = true

  canvases = [document.getElementById("stage-1"), document.getElementById("stage-2")]
  contexts = _.map canvases, (canvas) -> canvas.getContext("2d")

  _.each document.querySelectorAll("img[id^='sprite-']"), (img) ->
    sprites[img.getAttribute("id").replace(/^sprite-/, "")] = img

  cityId = location.search.match /cityId=([0-9]+)/

  if cityId
    cityId = cityId[1]

    img = document.createElement "img"
    img.setAttribute "src", "cities/#{ cityId }.png"
    document.body.appendChild img
    sprites["city-#{ cityId }"] = img
    img.addEventListener "load", ->
      _.defer ->
        startRound 0, cityId
  else
    startRound 0

addEventListener "load", init
