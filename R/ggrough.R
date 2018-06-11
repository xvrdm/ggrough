#' Create a new ggRough chart
#'
#' @export
ggrough <- function(data, width = NULL, height = NULL, elementId = NULL) {

  # forward options using x
  x = list(
    data=data
  )

  # create widget
  htmlwidgets::createWidget(
    name = 'ggrough',
    x = x,
    width = width,
    height = height,
    package = 'ggrough',
    elementId = elementId
  )
}

