
#' @title get image annotations
#' @name get_annotations
#' @description
#' Calls the 'Google Vision' API to return annotations. The function automatically creates batches
#' @param images
#' A character vector for images to be annotated. Can either be url strings or local images, as specified with \code{mode}.
#' @param features
#' A character vector for the features to be returned. Accepts \code{'all'} or any combination of the following inputs: \code{'label', 'web', 'text', 'face', 'landmark', 'logo', 'safe_search', 'object', 'properties'}
#' @param max_res
#' An integer specifying the maximum number of results to be returned for each feature.
#' @param mode
#' Accepts \code{'url'} for image urls and \code{'local'} for file paths to local images.
#' @return An response object of class \code{'gvision_annotations'}.
#' @seealso Google Vision \href{https://cloud.google.com/vision/docs/features-list}{features} and \href{https://cloud.google.com/vision/quotas}{quotas}.
#' @export
#'
#' @examples
#' \dontrun{
#'
#'  gvision_init()
#'
#'  # one image url
#'  sw_image <- 'https://upload.wikimedia.org/wikipedia/en/4/40/Star_Wars_Phantom_Menace_poster.jpg'
#'  results <- get_annotations(images = sw_image, # image character vector
#'                            features = 'all', # request all available features
#'                            max_res = 10, # maximum number of results per feature
#'                            mode = 'url')  # maximum number of results per feature
#'
#'  # multiple image urls
#'  finn_image <- 'https://upload.wikimedia.org/wikipedia/en/2/2a/Finn-Force_Awakens_%282015%29.png'
#'  padme_image <- 'https://upload.wikimedia.org/wikipedia/en/e/ee/Amidala.png'
#'
#'  input_imgs <- c(sw_image, finn_image, padme_image)
#'  results <- get_annotations(images = input_imgs,
#'             features = c('label', 'face'), max_res = 5, mode = 'url')
#'             
#'  # one local image
#'  temp_img_path <- tempfile(fileext = '.png')
#'  download.file(finn_image, temp_img_path, mode = 'wb', quiet = TRUE)
#'
#'  results <- get_annotations(images = temp_img_path,
#'             features = c('label', 'face'), max_res = 5, mode = 'local')
#'  }
#'
#'
#'
get_annotations <- function(images, features, max_res, mode) {

  if (!is.character(images)) {
    stop('"images" excepts a character vector for either image urls or local file paths.')

  }

  for (feat in features) {
    if (!feat %in% c('all', .imgrec$valid_features)) {
      stop('invalid "features" provided. Check the documentation for valid features.')
    }
  }

  if (!max_res %% 1 == 0 || max_res <= 0) {
    stop('"max_res" only accepts positive integers.')

  }

  if (!mode %in% c('url', 'local')) {
    stop('only "url" for image urls and "local" for image file paths are accepted as "mode".')

  }
  # build chunks for multiple images
  image_chunks <- build_chunks(images)
  # build query for API call
  query <- build_requests(images = images,
                          features = features,
                          max_res = max_res, mode = mode)
  # call the API
  results <- get_requests(query)
  # merge API data with image names
  combined <- list(ids = image_chunks, data = results)
  class(combined) <- 'gvision_annotations'
  return(combined)
}


