#' @title parse image annotations
#' @name parse_annotations
#' @description
#' Parses the annotations and converts most of the features to data frames. Also stores the corresponding image identifiers for each feature as \code{'img_id'}
#' @param annotations
#' An annotation object created with \code{\link[imgrec]{get_annotations}}.
#' @return A list containing data frames for each feature:
#' \describe{
#'   \item{labels}{label annotations}
#'   \item{web_labels}{web label annotations}
#'   \item{web_similar}{similar web images}
#'   \item{web_match_partial}{partial matching web images}
#'   \item{web_match_full}{full matching web images}
#'   \item{web_match_pages}{matching web pages}
#'   \item{faces}{face annotations}
#'   \item{objects}{object annotations}
#'   \item{logos}{logo annotations}
#'   \item{landmarks}{landmark annotations}
#'   \item{full_text}{full text annotation}
#'   \item{safe_serarch}{safe search annotation}
#'   \item{colors}{dominant color annotations}
#'   \item{crop_hints}{crop hints for ratios 0.8/1.0/1.2}
#' }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # initialize api credentials
#' gvision_init()
#'
#' # annotate images
#' finn_image <- 'https://upload.wikimedia.org/wikipedia/en/2/2a/Finn-Force_Awakens_%282015%29.png'
#' sw_image <- 'https://upload.wikimedia.org/wikipedia/en/8/82/Leiadeathstar.jpg'
#' padme_image <- 'https://upload.wikimedia.org/wikipedia/en/e/ee/Amidala.png'
#'
#' results <- get_annotations(images = c(finn_image, sw_image, padme_image),
#'                            features = 'all', max_res = 10, mode = 'url')
#' # parse annotations
#' img_data <- parse_annotations(results)
#'
#' # available feature data frames
#' names(img_data)
#'   }
#'   



parse_annotations <- function(annotations) {
  if (!class(annotations) == 'gvision_annotations') {
    stop('"this function only accepts annotation object')
  }

  # convert JSON to R objects
  requests <- parse_requests(annotations)
  data_frames <- list()

  # iterate over all requests
  for (req in seq_along(requests)) {
    img_id <- names(requests)[req]
    dat <- requests[[req]]
    
    if(!is.null(dat[['error']])) {
      print(paste0('Error for ', img_id))
      print(paste0('API message: ', dat$error$message))
      next
    }

    # parse labels
    if (!is.null(dat[['labelAnnotations']])) {

      labels <- parse_labels(dat$labelAnnotations, img_id)
      data_frames$labels <- bind_rows(data_frames$labels, labels)
    }

    # parse web features
    if (!is.null(dat[['webDetection']])) {

      web <- parse_web(dat[['webDetection']], img_id)

      if (!is.null(web[['labels']])) {
        data_frames$web_labels <- bind_rows(data_frames$web_labels,
                                            web[['labels']])
      }

      if (!is.null(web[['similar']])) {
        data_frames$web_similar <- bind_rows(data_frames$web_similar,
                                             web[['similar']])
      }

      if (!is.null(web[['partial']])) {
        data_frames$web_match_partial <-
          bind_rows(data_frames$web_match_partial,
                    web[['partial']])
      }

      if (!is.null(web[['full']])) {
        data_frames$web_match_full <- bind_rows(data_frames$web_match_full,
                                                web[['full']])
      }


      if (!is.null(web[['pages']])) {
        data_frames$web_match_pages <-
          bind_rows(data_frames$web_match_pages,
                    web[['pages']])
      }

      if (!is.null(web[['bestguess']])) {
        data_frames$web_best_guess <- bind_rows(data_frames$web_best_guess,
                                            web[['bestguess']])
      }
      

    }

    # parse faces
    if (!is.null(dat[['faceAnnotations']])) {

      faces <- parse_faces(dat$faceAnnotations, img_id)
      data_frames$faces <- bind_rows(data_frames$faces, faces)
    }

    # parse objects
    if (!is.null(dat[['localizedObjectAnnotations']])) {

      objects <-
        parse_objects(dat$localizedObjectAnnotations, img_id)
      data_frames$objects <- bind_rows(data_frames$objects, objects)
    }

    # parse logos
    if (!is.null(dat[['logoAnnotations']])) {

      logos <- parse_logos(dat$logoAnnotations, img_id)
      data_frames$logos <- bind_rows(data_frames$logos, logos)
    }

    # parse landmarks
    if (!is.null(dat[['landmarkAnnotations']])) {

      landmarks <- parse_landmarks(dat$landmarkAnnotations, img_id)
      data_frames$landmarks <-
        bind_rows(data_frames$landmarks, landmarks)
    }

    # parse full texts
    if (!is.null(dat[['fullTextAnnotation']])) {

      full_text <- parse_text(dat$fullTextAnnotation, img_id)
      data_frames$full_text <-
        bind_rows(data_frames$full_text, full_text)
    }

    # parse safe search
    if (!is.null(dat[['safeSearchAnnotation']])) {

      safe_search <-
        parse_safe_search(dat$safeSearchAnnotation, img_id)
      data_frames$safe_search <-
        bind_rows(data_frames$safe_search, safe_search)
    }

    # parse colors
    if (!is.null(dat[['imagePropertiesAnnotation']][['dominantColors']][['colors']])) {

      colors <-
        parse_colors(dat$imagePropertiesAnnotation$dominantColors$colors,
                     img_id)
      data_frames$colors <- bind_rows(data_frames$colors, colors)
    }

    # parse crop hints
    # deactivated for now as the API does not return complete bounding polys

     if (!is.null(dat[['cropHintsAnnotation']][['cropHints']])) {
       crop_hints <- parse_crop_hints(dat$cropHintsAnnotation$cropHints, img_id)
       data_frames$crop_hints <- bind_rows(data_frames$crop_hints, crop_hints)
     }

  }

  return(data_frames)

}
