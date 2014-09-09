system = require('system')
fs = require('fs')

page = require('webpage').create()
page.viewportSize = { width: 640, height: 350 }

cityId = system.args[1]
path = system.args[2] || "."

fs.makeDirectory("#{ path }/#{ cityId }")

page.open "http://localhost:8000/index.html?mode=manual&cityId=#{ cityId }", ->
  setTimeout ->
    stage = { round: 1 }
    frame = 0
    turn = null

    rendering = true
    while rendering
      stage = page.evaluate ->
        next()

      rendering = (stage.round == 0 && stage.turnCount >= 0)

      if rendering
        turnKey = stage.turnCount.toString()
        turnKey = "0" + turnKey if (stage.turnCount < 10)
        turnKey = "0" + turnKey if (stage.turnCount < 100)

        if turn != stage.turnCount
          turn = stage.turnCount
          console.log "* Saving turn #{ turn }"
          frame = 0
          fs.makeDirectory("#{ path }/#{ cityId }/#{ turnKey }")

        frameKey = frame.toString()
        frameKey = "0" + frameKey if (frame < 10)
        frameKey = "0" + frameKey if (frame < 100)
        page.render "#{ path }/#{ cityId }/#{ turnKey }/#{ frameKey }.png"
      
      frame++

    phantom.exit()
  , 1000
