
#' @title ave annotation data as JSON
#' @name save_json
#' @description
#' Writes raw JSON data as returned by the Google Vision API to a UTF-8 encoded local file.
#' @param annotations
#' An annotation object created with \code{\link[imgrec]{get_annotations}}.
#' @param file
#' Local path where the JSON data should be stored.
#' @return nothing.
#' @export
#'
#' @examples
#' \dontrun{
#'  gvision_init()
#'
#'  finn_image <- 'https://upload.wikimedia.org/wikipedia/en/2/2a/Finn-Force_Awakens_%282015%29.png'
#'  results <- get_annotations(images = finn_image, features = 'all',
#'                             max_res = 10, mode = 'url')
#'  temp_file_path <- tempfile(fileext = '.json')
#'  save_json(results, temp_file_path)
#'   }



save_json <- function(annotations, file) {
  if(!class(annotations) == 'gvision_annotations') {
    stop('this function only accepts annotation object')
  }
  # open file connection
  conn <- file(file, open = "w", encoding = "UTF-8")
  # writing requests to file
  requests <- unlist(annotations$requests)
  to_write <- c('[', paste( requests,  collapse = ", ", sep = ""), ']')
  write(to_write, conn)
  # close file connection
  close(conn)
}
