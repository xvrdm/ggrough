function hexToRgb(hex) {
   /**
    * Convert hex strings to object {r:Int, g:Int, b:Int}.
    *
    * Used to isolate numbers for colors and converting them to Int
    * so that they can be used in `rgb(r,g,b)` and `rgba(r,g,b,a)` calls.
    *
    * @param {String} hex - A Hex color string (e.g "#FF0000")
    *
    * @return {Object} A object with Integer values for each colors
    * (e.g {r:255, g:234, b:123})
    */
  var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : null;
}


function getHachureAngle(angle, angle_noise) {
  /**
   * Calculate an angle for hachure modifying variable angle with angle_noise.
   *
   * angle_noise is a value between 0 and 1, equivalent to the percentage of
   * possible deviation from the set angle. An angle_noise of 1 means
   * that deviation up to 90 degrees are allowed.
   *
   * @param {Number} angle - the angle of hachure
   * @param {Number} angle_noise - the % of 90° variation allowed around angle
   *
   * @return {Number} a hachure angle.
   */
  let max_angle = angle_noise < 1 ? 90 * angle_noise / 2 : 90 * 1 / 2;
  let plusOrMinus = Math.random() < 0.5 ? -1 : 1;
  return angle + plusOrMinus * Math.random() * max_angle;
}

function getHachureGap(gap, gap_noise) {
  /**
   * Calculate a hachure gap, modifying variable gap with gap_noise.
   *
   * gap_noise is a value between 0 and 1, equivalent to the percentage of
   * possible deviation from the set gap. A gap_noise of 1 means
   * that deviation up to 2*gap are allowed.
   *
   * @param {Number} gap - the gap of hachure
   * @param {Number} gap_noise - the % of variation allowed around gap
   *
   * @return {Number} a hachure gap.
   */
  let max_gap = gap_noise < 1 ? gap * gap_noise : gap;
  let plusOrMinus = Math.random() < 0.5 ? -1 : 1;
  return gap + plusOrMinus * Math.random() * max_gap;
}

function getFillRGB(style, alphaOver) {
  /**
   * Parse svg style attributes to create a `rgba(r,g,b,a)` string for fill.
   *
   * When there is no set `fill-opacity` attribute, 1 (100%) is used.
   *
   * @param {Object} style - The style attributes from a svg element
   *
   * @return {String} A "rgba" string (e.g "rgba(255, 166, 34, 0.2)")
   */
  let fill = undefined;
  let opacity = 1 / alphaOver;
  if (style !== null && typeof style === 'object' && "fill" in style) {
    let {r, g, b} = hexToRgb(style.fill);
    if ("fill-opacity" in style) {
      opacity = Number(style["fill-opacity"]) / alphaOver
    }
    fill = "rgba(" + r + "," + g + "," + b + "," + opacity +")";
  }
  return fill
}

function getFillObject(s) {
  /**
   * Create an object with all roughjs options for fill.
   *
   * There is a lot more than just the fill color to set: fillStyle (hachure vs
   * solid), fillWeight, angle, gap... See https://github.com/pshihn/rough/wiki
   * This method also permit to use angle_noise via getHachureAngle,
   * which calculate the angle value dynamically around the set angle.
   *
   * @return {Object} Object of roughjs options related to fill.
   * (e.g {fillStyle:..., hachureAngle:..., hachureGap:..., ...})
   *
   */
  let fillOptions = {};
  let {angle, angle_noise, gap, gap_noise} = s.rough_options;
  let {fill_weight, fill_style, alpha_over} = s.rough_options;
  if ("fill" in s.style) {
    fillOptions = {...fillOptions, ...{
      fill: getFillRGB(s.style, alpha_over),
      fillStyle: fill_style
    }};
    if (fill_style !== "solid") {
      fillOptions = {
        ...fillOptions,
        ...{
          fillWeight: fill_weight,
          hachureGap: getHachureGap(gap, gap_noise)
        }};
    }
    if (fill_style === "dots") {
      // Anything else than 1 seems to modify the position
      fillOptions = {...fillOptions, ...{roughness: 1}};
    }
    if (fill_style !== "solid" && fill_style !== "dots") {
      let hachureOptions = {
          hachureAngle: getHachureAngle(angle, angle_noise)
      };
      fillOptions = {...fillOptions, ...hachureOptions};
    }
  }
  return fillOptions;
}

function getStrokeRGB(style) {
  /**
   * Parse svg style attributes to create a `rgba(r,g,b,a)` string for stroke.
   *
   * When there is no set `stroke-opacity` attribute, 1 (100%) is used.
   *
   * @param {Object} style - The style attributes from a svg element
   *
   * @return {String} A "rgba" string (e.g "rgba(255, 166, 34, 0.2)")
   */
  let stroke = "rgba(255,255,255,0)";
  if (style !== null && typeof style === 'object' && "stroke" in style &&
    !(style.stroke == "none" || Number(style["stroke-width"]) == 0)) {
    let {r, g, b} = hexToRgb(style.stroke);
    opacity = "stroke-opacity" in style ? Number(style["stroke-opacity"]) : 1;
    stroke = "rgba(" + r + "," + g + "," + b + "," + opacity + ")";
  }
  return stroke
}

// Only pass style?
function getStrokeObject(s) {
  /**
   * Create an object with all roughjs options for stroke.
   *
   * @return {Object} Object of roughjs options related to stroke.
   * (e.g {stroke:..., strokeWidth:...})
   *
   */
  let strokeOptions = {};
  let stroke = s.style ? getStrokeRGB(s.style) : "rgba(255,255,255,0)";
  let strokeWidth = Number(s.style["stroke-width"]);
  strokeOptions =  {
    stroke: stroke,
    strokeWidth: strokeWidth,
  }
  return strokeOptions
}

function drawRect(rc, s) {
  /**
   * Draw rectangles
   *
   * Draw rectangles on rough canvas (rc)
   *
   * @param {Object} rc - Rough Canvas
   * @param {Object} s - Shape object coming from R
   *
   * @return {} Draw rectangle on rough canvas (rc)
   */
  let options = {
    bowing: s.rough_options.bowing,
    roughness: s.rough_options.roughness
  }
  options = {...options, ...getStrokeObject(s)};
  options = {...options, ...getFillObject(s)};

  for (i = 0; i < s.rough_options.alpha_over ; i++) {
    rc.rectangle(
      Number(s.x), Number(s.y), Number(s.width), Number(s.height),
      options);
  }
}

function drawCircle(rc, s) {
  /**
   * Draw circles
   *
   * Draw circles on rough canvas (rc)
   *
   * @param {Object} rc - Rough Canvas
   * @param {Object} s - Shape object coming from R
   *
   * @return {} Draw circle on rough canvas (rc)
   */
  let options = {
    bowing: s.rough_options.bowing,
    roughness: s.rough_options.roughness
  }
  options = {...options, ...getStrokeObject(s)};
  options = {...options, ...getFillObject(s)};

  rc.circle(
    Number(s.cx), Number(s.cy), Number(s.r.slice(0,-2))*4,
    options);
}



function drawLinearPath(rc, s) {
  /**
   * Draw non-closed lines
   *
   * Points for linearPath need to be given in an array of arrays:
   * [[x,y],[x,y],[x,y]...]. We get them from R as a space/comma separated
   * string: "x,y x,y x,y x,y ...".
   *
   * The lines that we don't want to draw (i.e the ones that were set to
   * element_blank() or alpha=0 in ggplot2) should come
   * with s.style.stroke === "none", so we exclude them from the drawing.
   *
   * @param {Object} rc - Rough Canvas
   * @param {Object} s - Shape object coming from R
   *
   * @return {} Draw linear Path on rough canvas (rc)
   */
  let pointsArrayStr = s.points.split(" ").map(x => x.split(","));
  let pointsArray = pointsArrayStr.map(x => x.map(y => Number(y)));

  let options = {
    bowing: s.rough_options.bowing,
    roughness: s.rough_options.roughness
  }
  options = {...options, ...getStrokeObject(s)};

  if (s.style.stroke !== "none") {
    rc.linearPath(pointsArray, options);
  }
}


function drawPath(rc, s) {
  /**
   * Draw closed lines (and fill if needed)
   *
   * Points for `path` need to come as a string "M...points...Z". The conversion
   * is done in R.
   *
   * @param {Object} rc - Rough Canvas
   * @param {Object} s - Shape object coming from R
   *
   * @return {} Draw closed path on rough canvas (rc)
   */
  let options = {
    bowing: s.rough_options.bowing,
    roughness: s.rough_options.roughness
  }
  options = {...options, ...getStrokeObject(s)};
  options = {...options, ...getFillObject(s)};

  rc.path(s.points, options);
}

function drawText(rc, s, ctx, font) {
  /**
   * Draw Text
   *
   * Rotated text comes from svg with a `transform` attribute in the shape
   * object rather than x and y. We need to extract the x and y, as well as
   * the orientation of the rotation (clock-wise vs counterclock-wise).
   *
   * Note that text is not rendered with a roughjs function but simply with
   * basic canvas functions.
   *
   * @param {Object} rc - Rough Canvas
   * @param {Object} s - Shape object coming from R
   * @param {Object} ctx - Canvas context object
   * @param {String} font - Optional font to override the one from the shape
   *
   * @return {} Draw text
   */
  let fontSize = Number(s.style["font-size"].slice(0,-2))
  if(font === undefined) {
    ctx.font =  fontSize + "px " + s.style["font-family"]
  } else {
    ctx.font = fontSize + "px " + font;
  }
  if("font-weight" in s) {ctx.font = s["font-weight"] + " " + ctx.font;}
  ctx.fillStyle = "fill" in s.style ? s.style.fill : "#000000";
  if("transform" in s) {
    console.log("YESSSS");
    let newc = s.transform.match(/\(([^)]+)\)/)[1].split(",").map(Number)
    let rotation = Number(s.transform.match(/rotate\((.*)\)/)[1]);
    ctx.save();
    ctx.translate(newc[0], newc[1]);
    if (rotation < 0) {
      ctx.rotate(-Math.PI/2);
    } else {
      ctx.rotate(Math.PI/2);
    }
    ctx.fillText(s.content, Number(0), Number(0));
    ctx.restore();
  } else {
    ctx.fillText(s.content, Number(s.x), Number(s.y));
  }
}


HTMLWidgets.widget({

  name: 'ggrough',

  type: 'output',

  factory: function(el, width, height) {

    return {
      renderValue: function(x) {

        // Create Canvas element in DOM
        var canvas = document.createElement("canvas");
        canvas.setAttribute("id", "canvas");
        canvas.setAttribute("width", width);
        canvas.setAttribute("height", height);
        el.appendChild(canvas);

        // Insert rough canvas in the new canvas element
        const rc = rough.canvas(document.getElementById("canvas"));

        // Create context for text shape
        const c = document.getElementById("canvas");
        var ctx = c.getContext("2d");

        x.data.map(function(s) {
          if (s.shape === "rect" && !(Array.isArray(s.style))) {
            drawRect(rc, s);
          }
          if (s.shape === "circle" && !(Array.isArray(s.style))) {
            drawCircle(rc, s);
          }
          if (s.shape === "path" && !(Array.isArray(s.style))) {
            drawPath(rc, s);
          }
          if (s.shape === "linearPath" && !(Array.isArray(s.style))) {
            drawLinearPath(rc, s);
          }
          if (s.shape === "text" && !(Array.isArray(s.style))) {
            drawText(rc, s, ctx);
          }
        })
      },
      resize: function(width, height) {
        // TODO: Find a way to redraw the image on resize.
      }
    }
  }
});
