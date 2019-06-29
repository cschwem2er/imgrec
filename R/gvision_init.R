
#' @title authorization for Google Vision
#' @name gvision_init
#' @description
#' Initializes the authorization credentials for the 'Google Vision' API.
#' Needs to be called before using any other functions of \code{imgrec} and requires \code{gvision_key} as environment variable.
#' @return nothing.
#' @export
#'
#' @examples
#' \dontrun{
#' Sys.setenv(gvision_key = "Your Google Vision API key")
#'
#' gvision_init()
#' }
#'
#'
#'
#'


gvision_init <- function() {

  gvision_key <- Sys.getenv('gvision_key')


  if (gvision_key == '') {
    stop('Could not load Google Vision authorization credentials from environment variables.')
  }
  header <- c('key' = gvision_key)
  assign("gvision_key", gvision_key, envir = .imgrec)
  message('Succesfully initialized authentification credentials.')

}

