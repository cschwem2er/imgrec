#' @importFrom base64enc base64encode
#' @importFrom jsonlite toJSON
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr tibble
#' @importFrom dplyr as_tibble
#' @importFrom dplyr bind_rows
#' @importFrom dplyr bind_cols
#' @importFrom dplyr rename
#' @importFrom httr POST
#' @importFrom httr modify_url
#' @importFrom httr content_type_json
#' @importFrom httr user_agent
#' @importFrom httr content
#' @importFrom rlang .data


.imgrec <- new.env(parent = emptyenv())


# parameters for google vision
.imgrec$gvision_url <- "https://vision.googleapis.com/"
.imgrec$gvision_annotate <-  "v1/images:annotate"
.imgrec$gvision_annotate_beta <- "v1p4beta1/images:annotate"
.imgrec$img_per_req <-  16

.imgrec$feature_table  <- list(label = "LABEL_DETECTION",
                               web = "WEB_DETECTION",
                               text = "TEXT_DETECTION",
                               face = "FACE_DETECTION",
                               landmark = "LANDMARK_DETECTION",
                               logo = "LOGO_DETECTION",
                               safe_search = "SAFE_SEARCH_DETECTION" ,
                               properties = "IMAGE_PROPERTIES",
                               object = "OBJECT_LOCALIZATION" )
.imgrec$valid_features <- names(.imgrec$feature_table)




build_chunks <- function(images) {
  # build request chunks for multiple images
  split(images, ceiling(seq_along(images)/.imgrec$img_per_req))
}


build_features <- function(features, max_res = 10) {
  # build feature table for requests
  all_feats <- list()
  if(features[1] == 'all') {
    features = .imgrec$valid_features
  }
  

  for (feat in seq_along(features)) {
    feature <- list(type = .imgrec$feature_table[[features[feat]]])
    if (!features[feat] %in% c('text')) {
      feature$maxResults <- max_res
    }

    
    all_feats <- append(all_feats, list(feature))
  }
  return(all_feats)
}



build_img <- function(img, features, max_res = 10, mode = 'url') {
  # build image objects
  img_obj <- list(image  = NULL, features = NULL)
  img_obj$features = build_features(features, max_res)

  if (mode == 'url') {
    img_obj$image$source$imageUri <- img
  } else  {
    img_obj$image$content <- base64encode(img)
  }
  
  
  if('properties' %in% features | 'all' %in% features) {
    img_obj$imageContext$cropHintsParams$aspectRatios <- c(0.8, 1, 1.2)
  }
  

  return (img_obj)
}


build_requests <- function(images, features, max_res, mode) {
  # build requests for the Google Vision API
  if(length(images) <= .imgrec$img_per_req) {
    query <- list(requests = list())
    for (img in seq_along(images)) {
      prep <- build_img(images[[img]], features, max_res, mode)
      query$requests <- append(query$requests, list(prep))
    }
    return(toJSON(query, auto_unbox = TRUE, pretty = FALSE))
  }
  else {
    print('Creating request batches..')
    all_queries <- list()
    chunks <- build_chunks(images)
    for (chunk in seq_along(chunks)) {
      query <- list(requests = list())
      for (img in seq_along(chunks[[chunk]])) {
        prep <- build_img(chunks[[chunk]][[img]], features, max_res, mode)
        query$requests <- append(query$requests, list(prep))
      }
      all_queries <- append(all_queries,toJSON(query,
                                               auto_unbox = TRUE, pretty = FALSE))
    }
    return(all_queries)
  }

}


check_error <- function(request) {
  # check whether API returned an error
  dat <- content(request)
  if ("error" %in% names(dat)) {
    stop(paste0('API Error ', dat$error$code, ': ', dat$error$message))
  }
}

get_requests <- function(query, api_version = 'stable') {
  # calling the Google Vision API
  all_requests <- list()
  print('Sending API request(s)..')
  for (q in seq_along(query)) {
    if (api_version == 'beta') {
      tocall <-   modify_url(.imgrec$gvision_url,
                             path =.imgrec$gvision_annotate_beta,
                             query = list(key = .imgrec$gvision_key))

    }

    else {
      tocall <- modify_url(.imgrec$gvision_url, path = .imgrec$gvision_annotate,
                           query = list(key = .imgrec$gvision_key))

    }


    request <- POST(tocall, body = query[[q]], content_type_json(),
                    user_agent('http://github.com/cschwem2er/imgrec'))
    check_error(request)
    data <- content(request, 'text')
    all_requests <- append(all_requests, data)

  }
  return(all_requests)
}



parse_requests <- function(requests) {
  # convert JSON request to R data structures
  ids <- requests$ids
  requests <- requests$data

  all_requests <- list()
  # converting to json
  for (req in seq_along(requests)) {
    data <-  fromJSON(requests[[req]], simplifyVector = FALSE)$responses
    names(data) <- ids[[req]]
    all_requests <- append(all_requests, data)
  }
  return(all_requests)
}



parse_faces <- function(faces, img_id) {
  # parse face data
  all_faces <- tibble()
  for (face in seq_along(faces)) {
    face_id <- face
    raw <- faces[[face]]
    poly <- do.call(bind_rows, raw$boundingPoly$vertices)
    poly_x_min <- min(poly$x)
    poly_y_min <- min(poly$y)
    poly_x_max <- max(poly$x)
    poly_y_max <- max(poly$y)
    raw$boundingPoly <- NULL
    raw$fdBoundingPoly <- NULL
    raw$landmarks <- NULL
    face_df <- as_tibble(raw)
    face_df$poly_x_min <- poly_x_min
    face_df$poly_y_min <- poly_y_min
    face_df$poly_x_max <- poly_x_max
    face_df$poly_y_max <- poly_y_max
    face_df$face_id <- paste0('f', face_id)
    face_df$img_id <- img_id
    all_faces <-  bind_rows(all_faces, face_df)

  }
  all_faces <- rename(all_faces,
           roll_angle = .data$rollAngle,
           pan_angle = .data$panAngle, 
           detection_confidence = .data$detectionConfidence ,
           landmark_confidence = .data$landmarkingConfidence ,
           joy_likelihood = .data$joyLikelihood ,
           sorrow_likelihood = .data$sorrowLikelihood ,
           anger_likelihood = .data$angerLikelihood,
           suprise_likelihood =  .data$surpriseLikelihood,
           under_exposed_likelihood =  .data$underExposedLikelihood,
           blurred_likelihood =  .data$blurredLikelihood, 
           headwear_likelihood = .data$headwearLikelihood)
  
  return(all_faces)
}



parse_objects <- function(objects, img_id) {
  # parse object data
  all_objects <- tibble()
  for (object in seq_along(objects)) {
    raw <- objects[[object]]
    poly <- do.call(bind_rows, raw$boundingPoly$normalizedVertices)
    # object poly are relative and thus need to be multiplied with
    # image width (x) and height (y) for visualization purposes
    poly_x_min <- min(poly$x, na.rm = TRUE)
    poly_y_min <- min(poly$y, na.rm = TRUE)
    poly_x_max <- max(poly$x, na.rm = TRUE)
    poly_y_max <- max(poly$y, na.rm = TRUE)
    raw$boundingPoly <- NULL
    object <- as_tibble(raw)
    object$polynorm_x_min <- poly_x_min
    object$polynorm_y_min <- poly_y_min
    object$polynorm_x_max <- poly_x_max
    object$polynorm_y_max <- poly_y_max
    object$img_id <- img_id
    all_objects <-  bind_rows(all_objects, object)


  }
  return(all_objects)
}

parse_logos <- function(logos, img_id) {
  # parse logo data
  all_logos <- tibble()
  for (logo in seq_along(logos)) {
    raw <- logos[[logo]]
    poly <- do.call(bind_rows, raw$boundingPoly$vertices)
    poly_x_min <- min(poly$x, na.rm = TRUE)
    poly_y_min <- min(poly$y, na.rm = TRUE)
    poly_x_max <- max(poly$x, na.rm = TRUE)
    poly_y_max <- max(poly$y, na.rm = TRUE)
    raw$boundingPoly <- NULL
    logo_df <- as_tibble(raw)
    logo_df$poly_x_min <- poly_x_min
    logo_df$poly_y_min <- poly_y_min
    logo_df$poly_x_max <- poly_x_max
    logo_df$poly_y_max <- poly_y_max
    logo_df$img_id <- img_id
    all_logos <-  bind_rows(all_logos, logo_df)


  }
  return(all_logos)
}

parse_landmarks <- function(landmarks, img_id) {
  # parse landmark data
  all_landmarks <- tibble()
  for (lm in seq_along(landmarks)) {
    raw <- landmarks[[lm]]
    poly <- do.call(bind_rows, raw$boundingPoly$vertices)
    poly_x_min <- min(poly$x, na.rm = TRUE)
    poly_y_min <- min(poly$y, na.rm = TRUE)
    poly_x_max <- max(poly$x, na.rm = TRUE)
    poly_y_max <- max(poly$y, na.rm = TRUE)
    geo <- as_tibble(latitude <- raw$locations[[1]]$latLng)
    raw$locations <- NULL
    raw$boundingPoly <- NULL
    lm_df <- as_tibble(raw)
    lm_df <- bind_cols(lm_df, geo)
    lm_df$poly_x_min <- poly_x_min
    lm_df$poly_y_min <- poly_y_min
    lm_df$poly_x_max <- poly_x_max
    lm_df$poly_y_max <- poly_y_max
    lm_df$img_id <- img_id

    all_landmarks <-  bind_rows(all_landmarks, lm_df)


  }
  return(all_landmarks)
}







parse_labels <- function(labels, img_id) {
  # parse label data
  label_df <- do.call(bind_rows, labels)
  label_df$img_id <- img_id
  return(label_df)
}

parse_safe_search <- function(searches, img_id) {
  # parse safe search data
  safe_search_df <- as_tibble(searches)
  safe_search_df$img_id <- img_id
  return(safe_search_df)
}

parse_colors <- function(colors, img_id) {
  # parse color data
  all_colors <- tibble()
  for (color in seq_along(colors)) {
    raw <- colors[[color]]
    if(length(raw$color) < 3) {
      next
    }
    cdata <- as_tibble(raw$color)


    color_df <- tibble(score  =  raw$score,
                       px_fraction =  raw$pixelFraction,
                       img_id =  img_id)
    color_df <- bind_cols(cdata, color_df)
    all_colors <-  bind_rows(all_colors, color_df)

  }
  return(all_colors)
}

parse_crop_hints <- function(crop_hints, img_id) {
  
  all_crops <- tibble()
  for (crop in seq_along(crop_hints)) {
    raw <- crop_hints[[crop]]
    poly <- do.call(bind_rows, raw$boundingPoly$vertices)
    # object poly are relative and thus need to be multiplied with
    # image width (x) and height (y) for visualization purposes
    poly_x_min <- min(poly$x, na.rm = TRUE)
    poly_y_min <- min(poly$y, na.rm = TRUE)
    poly_x_max <- max(poly$x, na.rm = TRUE)
    poly_y_max <- max(poly$y, na.rm = TRUE)
    raw$boundingPoly <- NULL
    crop_df <- as_tibble(raw)
    names(crop_df) <- c('confidence', 'importance_frac')
    crop_df$poly_x_min <- poly_x_min
    crop_df$poly_y_min <- poly_y_min
    crop_df$poly_x_max <- poly_x_max
    crop_df$poly_y_max <- poly_y_max
    crop_df$img_id <- img_id
    all_crops <-  bind_rows(all_crops, crop_df)
  }
  return(all_crops)
}


parse_text <- function(text, img_id) {
  # parse OCR full text data
  text_df <- tibble(text = text$text, img_id = img_id)
  return(text_df)
}




parse_web <- function(web, img_id) {
  # parse data from several web features
  web_results <- list()

  if (!is.null(web[['webEntities']])) {
    labels <- do.call(bind_rows, web$webEntities)
    labels$img_id <- img_id
    web_results$labels <- labels
  }

  if (!is.null(web[['visuallySimilarImages']])) {
    similar <- tibble(img_id = img_id,
                      similar_url = unlist(web$visuallySimilarImages))

    web_results$similar <- similar
  }

  if (!is.null(web[['partialMatchingImages']])) {
    partial <-
      tibble(partial_match_url = unlist(web$partialMatchingImages),
             img_id = img_id)

    web_results$partial <- partial
  }

  if (!is.null(web[['fullMatchingImages']])) {
    full <- tibble(full_match_url = unlist(web$fullMatchingImages),
                   img_id = img_id)

    web_results$full <- full
  }

  if (!is.null(web[['pagesWithMatchingImages']])) {
    web_matches <- tibble()

    for (m in seq_along(web$pagesWithMatchingImages)) {
      match <- web$pagesWithMatchingImages[[m]]
      match_df <- tibble()

      if (!is.null(match[['fullMatchingImages']])) {
        img_urls_full <- tibble(
          match_type = 'full',
          match_img_url =
            unlist(match$fullMatchingImages))
        match_df <- bind_rows(match_df, img_urls_full)

      }

      if (!is.null(match[['partialMatchingImages']])) {
        img_urls_partial <- tibble(
          match_type = 'partial',
          match_img_url =
            unlist(match$partialMatchingImages))
        match_df <- bind_rows(match_df, img_urls_partial)

      }

      match_df$match_page_url <- match$url
      match_df$page_title <- match$pageTitle



      web_matches <- bind_rows(web_matches, match_df)
    }
    web_results$pages <- web_matches
  }


  return(web_results)

}

