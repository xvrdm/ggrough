
#' Convert a named vector to a named list
#'
#' This function takes a named vector and convert it to a list with keys named
#' after the vector's names.
#'
#' @param nc A named vector
#' @return A list with keys matching nc names
nv_to_list <- function(nc) {
  split(unname(nc),names(nc))
}

#' Test if keys are in list
#'
#' This function takes a list and a vector of required keys. It returns TRUE
#' if all the required keys are in the list. Additional keys are allowed.
#'
#' @param l a list
#' @param req_keys a character vector of required keys
#' @return A boolean, TRUE if the required keys req_keys are all in list l
keys_check <- function(l, req_keys) {
  length(setdiff(req_keys,names(l)))==0
}

shape_constraints <- list(
  list(shape="rect",
       keys=c("x", "y", "width", "height")),
  list(shape="polyline",
       keys=NULL),
  list(shape="circle",
       keys=c("cx", "cy", "r"))
)


#' Convert XML node attributes (and optionally content) to a list
#'
#' This function extends `xml2::xml_attrs()`, by adding the option to add the
#' node content as an additional key `content` to the list created by
#' `xml2::xml_attrs()`.
#'
#' @param nodes an `xml2` `nodeset`
#' @param add_content a boolean
#'
#' @importFrom magrittr "%>%"
#' @return A list of character vectors
get_node_attrs <- function(nodes, add_content=F) {
  attrs <- nodes %>% xml2::xml_attrs()

  if (add_content) {
    texts <- xml2::xml_text(nodes)
    for (i in 1:length(texts)) {
      attrs[[i]][["content"]] <- texts[i]
    }
  }
  attrs
}


parse_shape <- function(svg, shape, keys, add_content=F) {
  svg %>%
    xml2::xml_ns_strip() %>%
    xml2::xml_find_all(stringr::str_glue("//{shape}")) %>%
    get_node_attrs(add_content) %>%
    purrr::keep(~keys_check(.x, keys)) %>%
    purrr::map(nv_to_list) %>%
    purrr::map(~purrr::list_modify(.x,
                                   shape=shape,
                                   style = parse_style_attrs(.x$style),
                                   `clip-path` = NULL))
}

#' Generate a ggplot gtable with only background elements
#'
#' This function copy a ggplot plot and set all its geoms to `alpha=0`/`size=0`.
#' `alpha=0` makes most elements invisible. `size=0` helps with some elements
#' not influenced by `alpha` like bar borders. The goal is to create a plot
#' object with just the background elements visible.
#'
#' NOTE: There are probably better way to do this but my attempts to remove
#' geoms ended up in recalculated scales.
#' See: https://stackoverflow.com/q/50434608/2008527
#'
#' The function also include a call to `correct_font()` which lets you
#' apply a multiplier to all text elements font sizes.
#'
#' @param p A ggplot plot
#' @param font_size_booster  A number for `correct_font`
#'
#' @return A ggplot gtable
generate_background_chart <- function(p, family, font_size_booster) {
  q <- ggplot2::ggplot_build(p) %>% correct_font(family, font_size_booster)
  q$data <- purrr::map(q$data, ~purrr::list_modify(.x, alpha=0, size=0))
  ggplot2::ggplot_gtable(q)
}

generate_containers_skeleton <- function(p, family, font_size_booster) {
  if (!(is.null(family))) {
    p <- p + ggplot2::theme(text = ggplot2::element_text(family=family))
  }

  # Starting with a chart without geom (only gridlines and background colors)
  charts_containers <- list(list(
    type="background_elements", geom="Background",
    chart=generate_background_chart(p, family, font_size_booster)))

  # Add one chart per geom (no gridlines nor background colors)
  for(layer_pos in 1:length(p$layers)) {
    mono_geom_chart <- p
    mono_geom_chart <- mono_geom_chart +
      ggplot2::theme(panel.grid.major.x = ggplot2::element_blank(),
            panel.grid.major.y = ggplot2::element_blank(),
            panel.grid.minor.x = ggplot2::element_blank(),
            panel.grid.minor.y = ggplot2::element_blank(),
            axis.ticks.x = ggplot2::element_blank(),
            axis.ticks.y = ggplot2::element_blank(),
            panel.background = ggplot2::element_blank(),
            panel.border = ggplot2::element_blank(),
            plot.background = ggplot2::element_blank())


    charts_containers <- append(
      charts_containers, list(list(
        type="mono_geom_chart",
        geom=class(mono_geom_chart$layers[[layer_pos]]$geom)[1],
        chart=ggplot2::ggplot_gtable(
          ggplot2::ggplot_build(mono_geom_chart) %>%
            correct_font(family, font_size_booster)))))
  }

  charts_containers
}


#' Add svg to chart_container object
#'
#' This function add a `svg` key containing a `svg` version of the chart in the
#' chart container.
#'
#' @param chart_container A chart_container
#'
#' @return A chart_container with svg key added
add_svgs_to_ggplot <- function(chart_container) {
  chart_container %>% purrr::list_modify(svg=plot_to_svg(.$chart))
}

table_to_svg <- function(gg_chart, width, height) {
  s <- svglite::svgstring(width = width, height = height); s()
  grid::grid.draw(gg_chart)
  s() -> svg_chart
  dev.off()
  svg_chart %>%
    as.character() %>%
    xml2::read_xml()
}

#' Add svg to chart_container object
#'
#' This function add a `svg` key containing a `svg` version of the chart in the
#' chart container. It uses the width and height of RStudio Viewer panel. There
#' are no API to grab this information, so we use `grDevices::dev.size` which
#' should be in sync with the Viewer panel. We use 0.9 to add a 10% margin.
#' See: https://stackoverflow.com/a/41401158/2008527
#'
#' @param chart_container A chart_container
#'
#' @return A chart_container with svg key added
add_svgs_to_table <- function(chart_container, width=NULL, height=NULL) {
  if (is.null(width)) { width <- grDevices::dev.size("in")[1]*0.90 }
  if (is.null(height)) { height <- grDevices::dev.size("in")[2]*0.90 }
  chart_container %>%
    purrr::list_modify(svg=table_to_svg(.$chart,
                                        width = width,
                                        height = height))
}


parse_svgs <- function(chart_container) {
  chart_container %>% purrr::list_modify(rough=parse_rough(.$svg,.$geom))
}

parse_circles <- function(svg) {
  shape <- "circle"
  keys  <- c("cx", "cy", "r")
  parse_shape(svg, shape, keys)
}

parse_lines <- function(svg) {
  shape <- "polyline"
  keys  <- NULL
  parse_shape(svg, shape, keys) %>%
  {purrr::map(., ~purrr::list_modify(
    .x,
    points=stringr::str_squish(.x$points),
    shape="linearPath"))}
}

parse_areas <- function(svg) {
  shape <- "polyline"
  keys  <- NULL
  parse_shape(svg, shape, keys) %>%
  {purrr::map(., ~purrr::list_modify(
    .x,
    points=stringr::str_squish(.x$points) %>% {stringr::str_glue("M{.}Z")},
    shape="path"))}
}

parse_rects <- function(svg) {
  shape <- "rect"
  keys  <- c("x", "y", "width", "height", "style")
  parse_shape(svg, shape, keys)
}

parse_texts <- function(svg) {
  shape <- "text"
  keys  <- c("style")
  parse_shape(svg, shape, keys, add_content = T)
}

correct_font <- function(gg_build, family=NULL, font_size_booster=1) {
  text_els <- c(
    "text",
    "axis.title",  "axis.text",
    "axis.title.x", "axis.title.x.top", "axis.title.y", "axis.title.y.right",
    "axis.text.x", "axis.text.x.top", "axis.text.y", "axis.text.y.right",
    "legend.text", "legend.title$size",
    "plot.title", "plot.subtitle", "plot.caption",
    "strip.text", "strip.text.x", "strip.text.y"
  )
  for (i in 1:length(text_els)){
    el <- text_els[i]
    s <- gg_build$plot$theme[[el]]$size
    if (is.numeric(s)) {
      gg_build$plot$theme[[el]]$size <- s * font_size_booster
    }

    f <- gg_build$plot$theme[[el]]$family
    #if (!(is.null(family)) && !(is.null(f)) && f != "") {
    if (!(is.null(family)) && is.character(f)) {
      gg_build$plot$theme[[el]]$family <- family
    }
  }
  gg_build
}

parse_rough <- function(svg, geom) {
  rough_els <- list()
  if (geom %in% c("GeomCol", "GeomBar", "GeomTile", "Background")) {
    rough_els <- append(rough_els, parse_rects(svg))
  }
  if (geom %in% c("GeomArea", "GeomViolin", "GeomSmooth", "Background")) {
    rough_els <- append(rough_els, parse_areas(svg))
  }
  if (geom %in% c("GeomPoint", "GeomJitter", "GeomDotPlot", "Background")) {
    rough_els <- append(rough_els, parse_circles(svg))
  }
  if (geom %in% c("GeomLine", "GeomSmooth", "Background")) {
    rough_els <- append(rough_els, parse_lines(svg))
  }
  if (geom %in% c("Background")) {
    rough_els <- append(rough_els, parse_texts(svg))
  }
  # Add a key with the name of the geom of origin
  purrr::map(rough_els, ~purrr::list_modify(.x, geom=geom))
}

add_rough_options <- function(chart_container, rough_user_options) {
  defaults <- list(
    fill_style = "solid",
    fill_weight = 4,
    roughness = 1.5,
    bowing = 1,
    simplification = 0,
    angle = 60,
    angle_noise = 0,
    gap = 6,
    gap_noise = 0,
    alpha_over = 1
  )

  rough_options <- defaults %>%
    purrr::list_modify(!!!rough_user_options[["defaults"]]) %>%
    purrr::list_modify(!!!rough_user_options[[chart_container[["geom"]]]])

  chart_container %>%
    purrr::list_modify(
      rough=purrr::map(.$rough, ~purrr::list_modify(
        .x, rough_options=rough_options)))
}

clean_up_elements <- function(elements) {
  elements %>%
    # Remove circle elements from the background layer
    purrr::discard(~(.x$shape == "circle" && .x$geom == "Background")) %>%

    # Set the roughness/bowing of axis grid lines to 0.5 max
    purrr::map_if(~(.x$shape == "path" && .x$geom == "Background"), purrr::list_modify,
                  rough_options=list(roughness=0.5, bowing=0.5)) %>%

    # Axis grid lines are duplicated in the SVG. We get a path plus a linearPath
    # elements. This get rid of the linearPath copy.
    purrr::discard(~(.$shape == "linearPath" && .$geom == "Background"))
}

parse_style_attrs <- function(style){
  style %>%
    stringr::str_split(";") %>%
    unlist() %>%
    stringr::str_split(":") %>%
    purrr::map(stringr::str_squish) %>%
    purrr::set_names(.,purrr::map_chr(.,1)) %>%
    purrr::keep(~length(.x)>1) %>%
    purrr::map(~.x[[2]])
}

create_chart_containers <- function(p, width, height, family, font_size_booster=1) {
  generate_containers_skeleton(p, family, font_size_booster) %>%
    purrr::map(add_svgs_to_table, width, height) %>%
    purrr::map(parse_svgs)
}

get_rough_elements <- function(p,
                               rough_user_options=NULL,
                               width=NULL, height=NULL,
                               family=NULL, font_size_booster=1) {
  create_chart_containers(p, width, height, family, font_size_booster) %>%
    purrr::map(add_rough_options, rough_user_options) %>%
    purrr::map("rough") %>%
    purrr::flatten() %>%
    clean_up_elements()
}

#' Create a roughjs chart
#' @export
get_rough_chart <- function(p, rough_user_options=NULL,
                            width=NULL, height=NULL,
                            family=NULL, font_size_booster=1) {
  get_rough_elements(p, rough_user_options, width, height, family, font_size_booster) %>%
    ggrough()
}



