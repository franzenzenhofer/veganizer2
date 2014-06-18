_DEBUG_ = false

dlog = (msg, debug = _DEBUG_) -> 
  console.log(msg) if debug
  return msg

window.dappend = (c, debug = _DEBUG_) -> 
  $('body').append(c) if debug
  return c

window.append = (c) -> 
  $('body').append(c) 
  return c

drawRotatedImage = (image, context, x=0, y=0, angle=0) -> 
  TO_RADIANS = Math.PI/180
  context.save();
  context.translate(x, y)
  context.rotate(angle * TO_RADIANS)
  context.drawImage(image, -(image.width/2), -(image.height/2))
  context.restore()
  return true

getBrightness = (r,g,b) -> (3*r+4*g+b)>>>3

brightnessSortForExtendedPixels = (a_extended,b_extended)-> 
  a = a_extended.color
  b = b_extended.color
  #sorty_value = ((3*a[0]+4*a[1]+a[2])>>>3) - ((3*b[0]+4*b[1]+b[2])>>>3)
  return getBrightness(a[0], a[1], a[2]) - getBrightness(b[0], b[1], b[2])

drawExtendedPixelWithPart = (ctx, part_to_draw, x = 0, y = 0, rotation = 0, mirror = false) ->
  if mirror
    drawRotatedImage(FE.mirror(part_to_draw.part), ctx, x, y, rotation)
  else
    drawRotatedImage(part_to_draw.part, ctx, x, y, rotation)
  return true



makeDrawByBrightness = (ctx, parts, pixel_w_h) ->
  nr_of_buckets = parts.length
  sorted_by_brightness_parts = parts.sort(brightnessSortForExtendedPixels)
  
  return (color,x,y,rotation=0, mirror=false, i) ->
    brightness = getBrightness(color[0], color[1], color[2])
    bucket_nr = Math.floor(brightness / 256 * nr_of_buckets)
    part_to_draw = sorted_by_brightness_parts[bucket_nr]
    drawExtendedPixelWithPart(ctx, part_to_draw, x*pixel_w_h, y*pixel_w_h, rotation, mirror)
    return [color,x,y,i]

extendPixels = (c) ->
  #create an array with extended veganized pixels
  rw = c.width
  rh = c.height
  rpx = []
  filter = (r,g,b,a, i) -> 
    pnr = Math.floor(i/4)
    rpx.push(
      y: Math.floor(pnr/rw)
      x: Math.floor(pnr%rw)
      color: [r,g,b,1.0]
      "rotation": _.random(0,360)
      "mirror": (if _.random(0,1) is 0 then false else true)
      pixel_nr: pnr
      )
  FE.rgba(c,filter,((c)->null))
  dlog(rpx)
  return rpx


createPixelyVersion = (c, max_w_h = 100) ->
  if c.width >= c.height
    rw = max_w_h
    rh = c.height * rw/c.width
  else
    rh = max_w_h
    rw = c.width * rh/c.height
  rw = Math.floor(rw)
  rh = Math.floor(rh)
  rc = FE.pixelyResize(c, rw, rh)
  #rc = pixelyResize(c, rw, rh)
  dappend(rc)
  return [rc, rw, rh] 

createIdealPixelWH = (parts, overlap) ->
  non_overlap = 1 - overlap
  pixel_w_h = 0
  for p in parts
    do (p) ->
      pixel_w_h = pixel_w_h + p.part.width + p.part.height
  pixel_w_h = Math.floor(pixel_w_h/(parts.length*2)*non_overlap)
  return pixel_w_h

n = () -> null


window.drawWithPicsInsteadOfPixels = (c, parts, overlap=0.3, before_cb = n, step_cb = n, final_cb = n) ->
  if overlap >= 1 then overlap = 0.65
  if overlap <0.2 then overlap = 0.2
  [rc, rw, rh] = createPixelyVersion(c, 100) 
  pixel_w_h = createIdealPixelWH(parts, overlap)
  dlog('pixel_w_h: '+pixel_w_h)
  [new_c, new_ctx] = dlog(FE.newCanvasToolbox(rw*pixel_w_h, rh*pixel_w_h))
  
  #extend and shuffle the pixels
  shuffeled_rpx = _.shuffle(extendPixels(rc))
  rpx_length = shuffeled_rpx.length
  draws_per_loop = 10
  before_cb(new_c)

  #we create our own very cool draw function
  draw = makeDrawByBrightness(new_ctx, parts, pixel_w_h)
  
  i = 0
  loop_i = 0
  total_loops = Math.ceil(shuffeled_rpx.length/draws_per_loop)
  do drawingLoop = () ->
    if i >= rpx_length
      final_cb(new_c)
    else
      for x in [0..draws_per_loop]
        do (x) ->
          p = shuffeled_rpx[i+x]
          if p then draw(p.color,p.x,p.y,p.rotation,p.mirror,i)
      step_cb(new_c, loop_i, total_loops) 
      
      i = i + draws_per_loop
      loop_i = loop_i + 1
      requestAnimationFrame(drawingLoop)

window.collectParts = (selector, cb) ->
  collector = []

  collectItAll = (part_canvas, rgb) ->
    if rgb and rgb.length is 3
        [r,g,b] = rgb
        collector.push({
        "part": part_canvas
        "color": [r,g,b,1.0]
        })
    else
      oneone = FE.pixelyResize(part_canvas,1,1)
      filter = (r,g,b,a,i) -> 
        collector.push({
        "part": part_canvas
        "color": [r,g,b,1.0]
        })
      FE.rgba(oneone,filter,((c)->null))
    
    #after we have collected all parts
    if collector.length is $(selector).size()
      _.each(collector, (p)->
        dappend($('<div><span style="background-color:rgba('+p.color[0]+','+p.color[1]+','+p.color[2]+','+p.color[3]+')">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span></div>'))
        dappend($(p.part))
        )
      cb(collector)

  $(selector).each((x)->
    data_rgb = false
    string_data_rgb = $(this).attr('data-rgb')
    if string_data_rgb
      data_rgb = _.map(string_data_rgb.split(','), ((x)->parseInt(x)))
    FE.byImage(this, (c)-> (collectItAll(c, data_rgb)))
    )
  return true

#before = (c) -> append(c)
#step = (c) -> dappend(c)
#finish = (c) -> dappend(c)
#
#collectParts('.parts', (parts)->
#  FE.byImage($('#testimage').get(0), (
#    (c)->drawWithPicsInsteadOfPixels(c, parts, 0.55, before, step, finish))
#  )
#)



