# Install required packages for LLM detection analysis
cat("Installing required R packages...\n\n")

# List of required packages
packages <- c(
  "jsonlite",
  "dplyr",
  "tidyr",
  "lubridate",
  "ggplot2",
  "plotly",
  "sentimentr",
  "stringr",
  "hunspell",
  "scales",
  "gridExtra",
  "viridis",
  "patchwork"
)

# Function to install if not already installed
install_if_missing <- function(pkg) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Installing %s...\n", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org", dependencies = TRUE)
  } else {
    cat(sprintf("%s already installed\n", pkg))
  }
}

# Install all packages
for (pkg in packages) {
  install_if_missing(pkg)
}

cat("\nAll packages installed successfully!\n")

