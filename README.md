
<!-- README.md is generated from README.Rmd. Please edit that file -->

# imgrec

[![Travis-CI Build
Status](https://travis-ci.org/cschwem2er/imgrec.svg?branch=master)](https://travis-ci.org/cschwem2er/imgrec)
[![AppVeyor Build
Status](https://ci.appveyor.com/api/projects/status/github/cschwem2er/imgrec?branch=master&svg=true)](https://ci.appveyor.com/project/cschwem2er/imgrec)
[![CRAN
status](https://www.r-pkg.org/badges/version/imgrec)](https://cran.r-project.org/package=imgrec)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/grand-total/imgrec)](https://cran.rstudio.com/web/packages/imgrec/index.html)

## Image Recognition with R

*imgrec* provides an interface for image recognition using the [Google
Vision API](https://cloud.google.com/vision/). It includes functions to
convert data for features such as object detection and optical character
recognition to data frames. The package also includes functions for
analyzing image annotations.

## How to Install

You can download and install the latest development version of imgrec
with the devtools package by running
`devtools::install_github('cschwem2er/imgrec')`.

For Windows users installing from github requires proper setup of
[Rtools](https://cran.r-project.org/bin/windows/Rtools/), for which a
tutorial is available
[here](https://github.com/stan-dev/rstan/wiki/Install-Rtools-for-Windows).

The package can also be installed from CRAN by running
`install.packages('imgrec')`.

## How to Use

### Authentification

Before loading *imgrec* you first need to initiate your authentification
credentials. You need an API key from a Google Project with access
permission for the Google Vision API. For this, you can first create a
project using the Google Cloud platform. The setup process is explained
in the API
[documentation](https://cloud.google.com/vision/docs/before-you-begin).
You will probably need to enable billing, but depending on your feature
selection up to 1000 requests per month are free (see
[pricing](https://cloud.google.com/vision/pricing)). Next following the
[instructions](https://cloud.google.com/docs/authentication/api-keys#creating_an_api_key)
for creating an API key. Finally, the API key needs to be set as
environment variable before using the initialization function
`gvision_init()`:

``` r
Sys.setenv(gvision_key = "Your Google Vision API key")
```

``` r
library(imgrec)
#> Warning: package 'imgrec' was built under R version 3.5.3
gvision_init()
#> Succesfully initialized authentification credentials.
```

In order to avoid calling `Sys.setenv`, you can permanently store the
API key in your `.Renviron`. I recommend `usethis::edit_r_environ()` to
find and edit your environment file.

### Image annotations

Google Vision accepts common file types such as JPG, PNG, or BMP. Images
can be passed to the function `get_annotations`, either as url strings
or file paths to local images. In the following example,
`get_annotations` is used to retrieve annotations for a poster of the
Star Wars movie [The Force
Awakens](https://en.wikipedia.org/wiki/Star_Wars:_The_Force_Awakens).

<img src='https://upload.wikimedia.org/wikipedia/en/a/a2/Star_Wars_The_Force_Awakens_Theatrical_Poster.jpg' width='250'>

``` r
sw_image <- 'https://upload.wikimedia.org/wikipedia/en/a/a2/Star_Wars_The_Force_Awakens_Theatrical_Poster.jpg'
results <- get_annotations(images = sw_image, # image character vector
                           features = 'all', # request all available features
                           max_res = 5, # maximum number of results per feature
                           mode = 'url') # determine image type
#> [1] "Sending API request(s).."
```

The function returns a response object from the Google Vision API. It
also recognizes if a user passes a character vector with multiple
images. In this case, request batches are created automatically to
reduce the number of required calls to the API. After retrieving
annotations, raw data can be stored in an UTF-8 encoded
[JSON](https://en.wikipedia.org/wiki/JSON) file:

``` r
temp_file_path <- tempfile(fileext = '.json')
save_json(results, temp_file_path)
```

While some users might prefer to work with raw `.json` data, which
includes every single detail returned by the API, the structure is quite
complex and deeply nested. To simplify the data, `parse_annotations`
converts most of the features to data frames. For each feature, the
original identifier of each image is included as `img_id`.

``` r
img_data <- parse_annotations(results) # returns list of data frames
names(img_data) # all available features
#>  [1] "labels"            "web_labels"        "web_similar"      
#>  [4] "web_match_partial" "web_match_full"    "web_match_pages"  
#>  [7] "objects"           "logos"             "full_text"        
#> [10] "safe_search"       "colors"            "crop_hints"
```

Once the features are converted to data frames, other R packages can be
used to analyze the data. For instance, the `labels` data frame contains
annotations about image content:

``` r
img_labels <- img_data$labels
head(img_labels)
```

| mid       | description    |     score | topicality | img\_id                                                                                            |
| :-------- | :------------- | --------: | ---------: | :------------------------------------------------------------------------------------------------- |
| /m/01n5jq | Poster         | 0.9679052 |  0.9679052 | <https://upload.wikimedia.org/wikipedia/en/a/a2/Star_Wars_The_Force_Awakens_Theatrical_Poster.jpg> |
| /m/02vxn  | Movie          | 0.9287522 |  0.9287522 | <https://upload.wikimedia.org/wikipedia/en/a/a2/Star_Wars_The_Force_Awakens_Theatrical_Poster.jpg> |
| /m/03c31  | Graphic design | 0.7759998 |  0.7759998 | <https://upload.wikimedia.org/wikipedia/en/a/a2/Star_Wars_The_Force_Awakens_Theatrical_Poster.jpg> |
| /m/0218rg | Flyer          | 0.6593872 |  0.6593872 | <https://upload.wikimedia.org/wikipedia/en/a/a2/Star_Wars_The_Force_Awakens_Theatrical_Poster.jpg> |
| /m/011s0  | Advertising    | 0.6283476 |  0.6283476 | <https://upload.wikimedia.org/wikipedia/en/a/a2/Star_Wars_The_Force_Awakens_Theatrical_Poster.jpg> |

The package also extracts bounding polygons for logos, objects, faces
and landmarks. We can for instance visualize all recognized logos of the
Star Wars movie poster with
[magick](https://CRAN.R-project.org/package=magick) and
[ggplot2](https://CRAN.R-project.org/package=ggplot2):

``` r
library(magick)
library(ggplot2)
img <- image_read(sw_image)
```

``` r
image_ggplot(img) + 
   geom_rect(data = img_data$logos, 
          aes(xmin = poly_x_min, xmax = poly_x_max, 
              ymin = poly_y_min, ymax = poly_y_max),
              color = 'yellow', fill = NA, linetype = 'dashed', size = 2) +
   geom_text(data = img_data$logos, 
          aes(x =poly_x_max, y = poly_y_max, label = description),
              size = 8, color = "yellow", vjust = 1) +
  theme(legend.position="none")
```

<img src="man/figures/sw_logo_rec.png" width="300">

Please note that for *object recognition* data, bounding polygons are
relative to image dimensions. Therefore, you need to multiply them with
image width (x) and height (y). These attributes are not returned by
Google Vision, but can for instance be identified with
`magick::image_info()`:

``` r
img_info <- image_info(img) 
img_info
#> # A tibble: 1 x 7
#>   format width height colorspace matte filesize density
#>   <chr>  <int>  <int> <chr>      <lgl>    <int> <chr>  
#> 1 JPEG     220    322 sRGB       FALSE   136703 28x28
```

Additional functions for feature analysis are currently in development.

## Citation

Please cite *imgrec* if you use the package for
    publications:

    Carsten Schwemmer (2019). imgrec: Image Recognition. R package version 0.1.0.
    https://CRAN.R-project.org/package=imgrec

A BibTeX entry for LaTeX users is:

    @Manual{,
      title = {imgrec: Image Recognition},
      author = {Carsten Schwemmer},
      year = {2019},
      note = {R package version 0.1.0},
      url = {https://CRAN.R-project.org/package=imgrec},
    }
