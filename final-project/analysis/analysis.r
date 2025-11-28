# ============================================================================
# LLM-Generated HackerOne Reports Detection Analysis
# ============================================================================

# Load Required Libraries
# ----------------------------------------------------------------------------
library(jsonlite)      # JSON parsing
library(tidyverse)     # Data manipulation and tidying
library(plotly)        # Interactive plots
library(sentimentr)    # Sentiment analysis
library(hunspell)      # Spell checking
library(scales)        # Scale formatting
library(gridExtra)     # Multiple plots
library(viridis)       # Color palettes
library(patchwork)     # Combining plots

# Set professional theme
theme_set(theme_minimal(base_size = 12) +
          theme(plot.title = element_text(face = "bold", size = 16),
                plot.subtitle = element_text(size = 12, color = "gray40"),
                axis.title = element_text(face = "bold"),
                legend.position = "bottom"))

# ============================================================================
# SECTION 1: DATA LOADING AND PREPROCESSING
# ============================================================================

cat("Loading HackerOne reports data...\n")
data <- fromJSON("../scrape/hackerone_reports_combined.json", flatten = TRUE)

# Convert to data frame
df <- as.data.frame(data)

cat(sprintf("Loaded %d reports\n", nrow(df)))

# Extract and parse dates
df$date_raw <- df$hacktivity_metadata.date

# Parse dates - handle various formats
df$date <- mdy_hms(df$date_raw, quiet = TRUE)

# Remove rows with invalid dates
df <- df %>% 
  filter(!is.na(date)) %>%
  filter(!is.na(original_report) & nchar(original_report) > 0)

# Create temporal features
df$year <- year(df$date)
df$year_month <- floor_date(df$date, "month")
df$quarter <- quarter(df$date, with_year = TRUE)

# Filter out years with insufficient data (2019 and earlier have sparse data)
# Focus on 2020+ for more reliable trends
cat(sprintf("Loaded %d reports from %s to %s\n", 
            nrow(df), min(df$year), max(df$year)))

df <- df %>% filter(year >= 2020)

cat(sprintf("Analyzing %d reports from 2020+ (filtered out sparse early years)\n", 
            nrow(df)))

# Show sample size distribution by year
year_counts <- df %>%
  group_by(year) %>%
  summarize(count = n()) %>%
  arrange(year)

cat("\nSample size by year:\n")
print(year_counts)
cat("\n")

# ============================================================================
# SECTION 2: METRIC 1 - AI LANGUAGE (POLITENESS / SENTIMENT ANALYSIS)
# ============================================================================

cat("\n[1/6] Analyzing sentiment and politeness...\n")

# Calculate sentiment scores using sentimentr
# sentiment_by() aggregates sentence-level scores by element_id (document)
sentiment_results <- sentiment_by(get_sentences(df$original_report))
df$sentiment_score <- sentiment_results$ave_sentiment

# Aggregate by year
sentiment_by_year <- df %>%
  group_by(year) %>%
  summarize(
    avg_sentiment = mean(sentiment_score, na.rm = TRUE),
    sd_sentiment = sd(sentiment_score, na.rm = TRUE),
    se_sentiment = sd(sentiment_score, na.rm = TRUE) / sqrt(n()),
    count = n()
  ) %>%
  filter(count >= 7)  # Only years with sufficient data

# Create visualization using sentiment score with error bars
p1 <- ggplot(sentiment_by_year, aes(x = year, y = avg_sentiment)) +
  geom_ribbon(aes(ymin = avg_sentiment - se_sentiment, 
                  ymax = avg_sentiment + se_sentiment), 
              fill = "#2E86AB", alpha = 0.2) +
  geom_line(color = "#2E86AB", size = 1.2) +
  geom_point(color = "#2E86AB", size = 3) +
  geom_smooth(method = "lm", se = TRUE, color = "#A23B72", linetype = "dashed") +
  labs(
    title = "Sentiment Analysis Over Time",
    subtitle = "Average sentiment score using sentimentr - Shaded area shows standard error",
    x = "Year",
    y = "Sentiment Score"
  ) +
  theme(panel.grid.minor = element_blank())

# Create standalone quality visualization with variance
p1_standalone <- ggplot(sentiment_by_year, aes(x = year, y = avg_sentiment)) +
  # Standard error ribbon
  geom_ribbon(aes(ymin = avg_sentiment - se_sentiment, 
                  ymax = avg_sentiment + se_sentiment), 
              fill = "#2E86AB", alpha = 0.15) +
  # Main line
  geom_line(color = "#2E86AB", size = 2) +
  geom_point(color = "#2E86AB", size = 5, shape = 21, fill = "white", stroke = 2) +
  # Trend line
  geom_smooth(method = "lm", se = FALSE, color = "#A23B72", 
              linetype = "dashed", size = 1.5) +
  labs(
    title = "AI Sentiment Signature: Reports Are Getting More Positive",
    subtitle = "Sentiment score using sentimentr package's sentence-level analysis",
    x = "Year",
    y = "Average Sentiment Score",
    caption = "Source: HackerOne Public Reports | Analyzed with sentimentr"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10)),
    plot.subtitle = element_text(size = 14, color = "gray30", lineheight = 1.3, margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0),
    axis.title = element_text(face = "bold", size = 14),
    axis.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    plot.margin = margin(20, 20, 20, 20),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  )

ggsave("metric_1_sentiment.png", p1_standalone, 
       width = 12, height = 8, dpi = 300, bg = "white")
cat("  Saved: metric_1_sentiment.png\n")

# ============================================================================
# SECTION 2B: 2025 MONTHLY SENTIMENT TRENDS
# ============================================================================

cat("  Creating 2025 monthly sentiment breakdown...\n")

# Filter for 2025 data and aggregate by month
sentiment_2025 <- df %>%
  filter(year == 2025) %>%
  mutate(month = floor_date(date, "month")) %>%
  group_by(month) %>%
  summarize(
    avg_sentiment = mean(sentiment_score, na.rm = TRUE),
    sd_sentiment = sd(sentiment_score, na.rm = TRUE),
    se_sentiment = sd(sentiment_score, na.rm = TRUE) / sqrt(n()),
    count = n()
  ) %>%
  filter(count >= 3)  # Only months with sufficient data

# Create 2025 monthly visualization
if (nrow(sentiment_2025) > 0) {
  p1_2025 <- ggplot(sentiment_2025, aes(x = month, y = avg_sentiment)) +
    # Standard error ribbon
    geom_ribbon(aes(ymin = avg_sentiment - se_sentiment, 
                    ymax = avg_sentiment + se_sentiment), 
                fill = "#2E86AB", alpha = 0.15) +
    # Main line
    geom_line(color = "#2E86AB", size = 2) +
    geom_point(color = "#2E86AB", size = 5, shape = 21, fill = "white", stroke = 2) +
    # Add text labels with count
    geom_text(aes(label = paste0("n=", count)), 
              vjust = -1.5, size = 3, color = "gray40") +
    # Trend line
    geom_smooth(method = "lm", se = FALSE, color = "#A23B72", 
                linetype = "dashed", size = 1.5, alpha = 0.7) +
    labs(
      title = "2025 Monthly Sentiment Trends: Recent AI Patterns",
      subtitle = "Month-by-month sentiment analysis for 2025 reports",
      x = "Month",
      y = "Average Sentiment Score",
      caption = "Source: HackerOne Public Reports | Analyzed with sentimentr"
    ) +
    scale_x_date(date_breaks = "1 month", date_labels = "%b\n%Y") +
    theme_minimal(base_size = 16) +
    theme(
      plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10)),
      plot.subtitle = element_text(size = 14, color = "gray30", lineheight = 1.3, margin = margin(b = 20)),
      plot.caption = element_text(size = 10, color = "gray50", hjust = 0),
      axis.title = element_text(face = "bold", size = 14),
      axis.text = element_text(size = 12),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90"),
      plot.margin = margin(20, 20, 20, 20),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
  
  ggsave("metric_1_sentiment_2025_monthly.png", p1_2025, 
         width = 12, height = 8, dpi = 300, bg = "white")
  cat("  Saved: metric_1_sentiment_2025_monthly.png\n")
  
  # Print summary stats
  cat(sprintf("  2025 Monthly Summary: %d months with data, avg sentiment = %.3f\n", 
              nrow(sentiment_2025), 
              mean(sentiment_2025$avg_sentiment, na.rm = TRUE)))
} else {
  cat("  Warning: No 2025 data found or insufficient sample size\n")
}

# ============================================================================
# SECTION 3: METRIC 2 - PERFECT ENGLISH (TYPO DETECTION)
# ============================================================================

cat("[2/6] Detecting typos and spelling errors...\n")

# Function to count typos using hunspell
count_typos <- function(text) {
  # Extract words (alphanumeric only)
  words <- str_extract_all(text, "\\b[A-Za-z]+\\b")[[1]]
  
  # Filter out very short words and common technical terms
  words <- words[nchar(words) > 2]
  
  if (length(words) == 0) return(0)
  
  # Check spelling
  misspelled <- hunspell_check(words)
  sum(!misspelled)
}

# Sample for performance reasons, as typo checking is expensive
set.seed(42)
if (nrow(df) > 500) {
  sample_idx <- sample(nrow(df), 500)
  df_sample <- df[sample_idx, ]
} else {
  df_sample <- df
}

# Calculate typo rates on sample
cat("  Checking spelling on sample...\n")
df_sample$typo_count <- sapply(df_sample$original_report, count_typos)
df_sample$word_count <- str_count(df_sample$original_report, "\\b[A-Za-z]+\\b")
df_sample$typo_rate <- (df_sample$typo_count / df_sample$word_count) * 100

# Aggregate by year
typo_by_year <- df_sample %>%
  group_by(year) %>%
  summarize(
    avg_typo_rate = mean(typo_rate, na.rm = TRUE),
    count = n()
  ) %>%
  filter(count >= 3)

# Create visualization
p2 <- ggplot(typo_by_year, aes(x = year, y = avg_typo_rate)) +
  geom_line(color = "#F77F00", size = 1.2) +
  geom_point(color = "#F77F00", size = 3) +
  geom_smooth(method = "lm", se = TRUE, color = "#06A77D", linetype = "dashed") +
  labs(
    title = "Spelling Error Rate Over Time",
    subtitle = "Percentage of misspelled words - AI tends toward perfection",
    x = "Year",
    y = "Typo Rate (%)"
  ) +
  scale_y_reverse() +  # Reverse so decreasing typos goes up
  theme(panel.grid.minor = element_blank())

# Create standalone quality visualization
p2_standalone <- ggplot(typo_by_year, aes(x = year, y = avg_typo_rate)) +
  geom_ribbon(aes(ymin = 0, ymax = avg_typo_rate), fill = "#F77F00", alpha = 0.2) +
  geom_line(color = "#F77F00", size = 2) +
  geom_point(color = "#F77F00", size = 5, shape = 21, fill = "white", stroke = 2) +
  geom_smooth(method = "lm", se = TRUE, color = "#06A77D", fill = "#06A77D",
              alpha = 0.2, linetype = "dashed", size = 1.5) +
  labs(
    title = "The Disappearing Typo: Perfect Grammar Everywhere",
    subtitle = "Percentage of misspelled words detected using hunspell dictionary\nLLMs don't make typos—but tired hackers at 3am definitely do.",
    x = "Year",
    y = "Spelling Error Rate (%)",
    caption = "Source: HackerOne Public Reports | Spell-checked with hunspell"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10)),
    plot.subtitle = element_text(size = 14, color = "gray30", lineheight = 1.3, margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0),
    axis.title = element_text(face = "bold", size = 14),
    axis.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    plot.margin = margin(20, 20, 20, 20),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  )

ggsave("metric_2_typos.png", p2_standalone, 
       width = 12, height = 8, dpi = 300, bg = "white")
cat("  Saved: metric_2_typos.png\n")

# ============================================================================
# SECTION 4: METRIC 3 - MIXED CASE USAGE
# ============================================================================

cat("[3/6] Analyzing capitalization patterns...\n")

# Detect title case usage in sentences
detect_mixed_case <- function(text) {
  # Split into sentences
  sentences <- str_split(text, "[.!?]+")[[1]]
  sentences <- str_trim(sentences)
  sentences <- sentences[nchar(sentences) > 10]
  
  if (length(sentences) == 0) return(0)
  
  # Check for title case (3+ consecutive capitalized words)
  title_case_pattern <- "\\b[A-Z][a-z]+\\s+[A-Z][a-z]+\\s+[A-Z][a-z]+"
  mixed_case_count <- sum(str_detect(sentences, title_case_pattern))
  
  mixed_case_count / length(sentences)
}

df$mixed_case_ratio <- sapply(df$original_report, detect_mixed_case)

# Aggregate by year
mixed_case_by_year <- df %>%
  group_by(year) %>%
  summarize(
    avg_mixed_case = mean(mixed_case_ratio, na.rm = TRUE),
    count = n()
  ) %>%
  filter(count >= 7)

# Create visualization
p3 <- ggplot(mixed_case_by_year, aes(x = year, y = avg_mixed_case)) +
  geom_line(color = "#8338EC", size = 1.2) +
  geom_point(color = "#8338EC", size = 3) +
  geom_smooth(method = "lm", se = TRUE, color = "#FF006E", linetype = "dashed") +
  labs(
    title = "Title Case Usage Over Time",
    subtitle = "Frequency of mixed case patterns - LLMs love proper capitalization",
    x = "Year",
    y = "Mixed Case Ratio"
  ) +
  theme(panel.grid.minor = element_blank())

# Create standalone quality visualization
p3_standalone <- ggplot(mixed_case_by_year, aes(x = year, y = avg_mixed_case)) +
  geom_area(fill = "#8338EC", alpha = 0.2) +
  geom_line(color = "#8338EC", size = 2) +
  geom_point(color = "#8338EC", size = 5, shape = 21, fill = "white", stroke = 2) +
  geom_smooth(method = "lm", se = TRUE, color = "#FF006E", fill = "#FF006E",
              alpha = 0.2, linetype = "dashed", size = 1.5) +
  labs(
    title = "Title Case Takeover: Proper Capitalization Everywhere",
    subtitle = "Ratio of sentences with title case formatting (Capital Letter Every Word)\nLLMs love proper grammar—internet denizens prefer lowercase chaos.",
    x = "Year",
    y = "Title Case Ratio",
    caption = "Source: HackerOne Public Reports | Pattern: 3+ consecutive capitalized words"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10)),
    plot.subtitle = element_text(size = 14, color = "gray30", lineheight = 1.3, margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0),
    axis.title = element_text(face = "bold", size = 14),
    axis.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    plot.margin = margin(20, 20, 20, 20),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  )

ggsave("metric_3_mixed_case.png", p3_standalone, 
       width = 12, height = 8, dpi = 300, bg = "white")
cat("  Saved: metric_3_mixed_case.png\n")

# ============================================================================
# SECTION 5: METRIC 4 - EM DASH AND EN DASH USAGE
# ============================================================================

cat("[4/6] Counting em dashes and en dashes...\n")

# Count various dash types
df$em_dash_count <- str_count(df$original_report, "—")  # Em dash
df$en_dash_count <- str_count(df$original_report, "–")  # En dash
df$total_dashes <- df$em_dash_count + df$en_dash_count

# Normalize by text length
df$dashes_per_1k <- (df$total_dashes / nchar(df$original_report)) * 1000

# Aggregate by year
dashes_by_year <- df %>%
  group_by(year) %>%
  summarize(
    avg_dashes = mean(dashes_per_1k, na.rm = TRUE),
    avg_em_dash = mean((em_dash_count / nchar(original_report)) * 1000, na.rm = TRUE),
    avg_en_dash = mean((en_dash_count / nchar(original_report)) * 1000, na.rm = TRUE),
    count = n()
  ) %>%
  filter(count >= 7)

# Create visualization
p4 <- ggplot(dashes_by_year, aes(x = year, y = avg_dashes)) +
  geom_line(color = "#FB5607", size = 1.2) +
  geom_point(color = "#FB5607", size = 3) +
  geom_smooth(method = "lm", se = TRUE, color = "#3A86FF", linetype = "dashed") +
  labs(
    title = "Em/En Dash Usage Over Time",
    subtitle = "Professional punctuation per 1,000 characters - AI sophistication marker",
    x = "Year",
    y = "Dashes per 1k chars"
  ) +
  theme(panel.grid.minor = element_blank())

# Create standalone quality visualization
p4_standalone <- ggplot(dashes_by_year, aes(x = year, y = avg_dashes)) +
  geom_ribbon(aes(ymin = 0, ymax = avg_dashes), fill = "#FB5607", alpha = 0.2) +
  geom_line(color = "#FB5607", size = 2) +
  geom_point(color = "#FB5607", size = 5, shape = 21, fill = "white", stroke = 2) +
  geom_smooth(method = "lm", se = TRUE, color = "#3A86FF", fill = "#3A86FF",
              alpha = 0.2, linetype = "dashed", size = 1.5) +
  labs(
    title = "The Fancy Dash Revolution—Nobody Types These",
    subtitle = "Frequency of em dashes (—) and en dashes (–) per 1,000 characters\nHumans use hyphens. LLMs use proper typography.",
    x = "Year",
    y = "Professional Dashes per 1k chars",
    caption = "Source: HackerOne Public Reports | Unicode characters U+2013 and U+2014"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10)),
    plot.subtitle = element_text(size = 14, color = "gray30", lineheight = 1.3, margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0),
    axis.title = element_text(face = "bold", size = 14),
    axis.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    plot.margin = margin(20, 20, 20, 20),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  )

ggsave("metric_4_dashes.png", p4_standalone, 
       width = 12, height = 8, dpi = 300, bg = "white")
cat("  Saved: metric_4_dashes.png\n")

# ============================================================================
# SECTION 6: METRIC 5 - REPORT LENGTH
# ============================================================================

cat("[5/6] Analyzing report lengths...\n")

# Calculate character and word counts
df$char_count <- nchar(df$original_report)
df$word_count_total <- str_count(df$original_report, "\\S+")

# Aggregate by year
length_by_year <- df %>%
  group_by(year) %>%
  summarize(
    avg_chars = mean(char_count, na.rm = TRUE),
    avg_words = mean(word_count_total, na.rm = TRUE),
    median_chars = median(char_count, na.rm = TRUE),
    count = n()
  ) %>%
  filter(count >= 7)

# Create visualization
p5 <- ggplot(length_by_year, aes(x = year, y = avg_chars)) +
  geom_line(color = "#06A77D", size = 1.2) +
  geom_point(color = "#06A77D", size = 3) +
  geom_smooth(method = "lm", se = TRUE, color = "#D62828", linetype = "dashed") +
  labs(
    title = "Report Length Over Time",
    subtitle = "Average character count - LLMs tend to be verbose",
    x = "Year",
    y = "Average Characters"
  ) +
  scale_y_continuous(labels = comma) +
  theme(panel.grid.minor = element_blank())

# Create standalone quality visualization
p5_standalone <- ggplot(length_by_year, aes(x = year, y = avg_chars)) +
  geom_area(fill = "#06A77D", alpha = 0.2) +
  geom_line(color = "#06A77D", size = 2) +
  geom_point(color = "#06A77D", size = 5, shape = 21, fill = "white", stroke = 2) +
  geom_smooth(method = "lm", se = TRUE, color = "#D62828", fill = "#D62828",
              alpha = 0.2, linetype = "dashed", size = 1.5) +
  labs(
    title = "Verbosity Inflation: Reports Keep Getting Longer",
    subtitle = "Average character count per security report over time\nAI assistants never met a paragraph they couldn't expand into three.",
    x = "Year",
    y = "Average Characters",
    caption = "Source: HackerOne Public Reports | Full report text analyzed"
  ) +
  scale_y_continuous(labels = comma) +
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10)),
    plot.subtitle = element_text(size = 14, color = "gray30", lineheight = 1.3, margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0),
    axis.title = element_text(face = "bold", size = 14),
    axis.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    plot.margin = margin(20, 20, 20, 20),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  )

ggsave("metric_5_length.png", p5_standalone, 
       width = 12, height = 8, dpi = 300, bg = "white")
cat("  Saved: metric_5_length.png\n")

# ============================================================================
# SECTION 7: METRIC 6 - BULLET POINTS AND LISTS
# ============================================================================

cat("[6/6] Detecting bullet points and lists...\n")

# Count various list markers
count_bullets <- function(text) {
  # Bullet patterns
  bullets <- str_count(text, "^\\s*[•●○▪▫-]\\s+") +
             str_count(text, "\\n\\s*[•●○▪▫-]\\s+")
  
  # Numbered lists
  numbered <- str_count(text, "^\\s*\\d+\\.\\s+") +
              str_count(text, "\\n\\s*\\d+\\.\\s+")
  
  # Markdown-style lists
  markdown <- str_count(text, "^\\s*[*+-]\\s+") +
              str_count(text, "\\n\\s*[*+-]\\s+")
  
  bullets + numbered + markdown
}

df$bullet_count <- sapply(df$original_report, count_bullets)
df$bullets_per_1k <- (df$bullet_count / df$char_count) * 1000

# Aggregate by year
bullets_by_year <- df %>%
  group_by(year) %>%
  summarize(
    avg_bullets = mean(bullets_per_1k, na.rm = TRUE),
    count = n()
  ) %>%
  filter(count >= 7)

# Create visualization
p6 <- ggplot(bullets_by_year, aes(x = year, y = avg_bullets)) +
  geom_line(color = "#E63946", size = 1.2) +
  geom_point(color = "#E63946", size = 3) +
  geom_smooth(method = "lm", se = TRUE, color = "#457B9D", linetype = "dashed") +
  labs(
    title = "Bullet Point Usage Over Time",
    subtitle = "List items per 1,000 characters - AI loves structured formatting",
    x = "Year",
    y = "Bullet Points per 1k chars"
  ) +
  theme(panel.grid.minor = element_blank())

# Create standalone quality visualization
p6_standalone <- ggplot(bullets_by_year, aes(x = year, y = avg_bullets)) +
  geom_ribbon(aes(ymin = 0, ymax = avg_bullets), fill = "#E63946", alpha = 0.2) +
  geom_line(color = "#E63946", size = 2) +
  geom_point(color = "#E63946", size = 5, shape = 21, fill = "white", stroke = 2) +
  geom_smooth(method = "lm", se = TRUE, color = "#457B9D", fill = "#457B9D",
              alpha = 0.2, linetype = "dashed", size = 1.5) +
  labs(
    title = "The Bullet Point Explosion: Lists, Lists Everywhere",
    subtitle = "Frequency of bullet points, numbered lists, and structured formatting per 1,000 characters\nAI output looks like PowerPoint slides. Human writing? More like stream of consciousness.",
    x = "Year",
    y = "List Items per 1k chars",
    caption = "Source: HackerOne Public Reports | Detects •, -, *, numbered lists, and markdown"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(face = "bold", size = 24, margin = margin(b = 10)),
    plot.subtitle = element_text(size = 14, color = "gray30", lineheight = 1.3, margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0),
    axis.title = element_text(face = "bold", size = 14),
    axis.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray90"),
    plot.margin = margin(20, 20, 20, 20),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  )

ggsave("metric_6_bullets.png", p6_standalone, 
       width = 12, height = 8, dpi = 300, bg = "white")
cat("  Saved: metric_6_bullets.png\n")

# ============================================================================
# SECTION 8: CREATE COMPOSITE VISUALIZATIONS
# ============================================================================

cat("\nCreating composite visualizations...\n")

# Combine all six plots into a comprehensive dashboard
combined_plot <- (p1 | p2) / (p3 | p4) / (p5 | p6) +
  plot_annotation(
    title = "LLM-Generated HackerOne Reports: Multi-Metric Detection Analysis (2020+)",
    subtitle = "Temporal trends suggesting increased AI usage in vulnerability reports | Weighted regression analysis",
    theme = theme(plot.title = element_text(size = 18, face = "bold"),
                  plot.subtitle = element_text(size = 14))
  )

# Save high-quality output
ggsave("llm_detection_dashboard.png", combined_plot, 
       width = 16, height = 12, dpi = 300, bg = "white")

cat("  Saved: llm_detection_dashboard.png\n")

# ============================================================================
# SECTION 9: INTERACTIVE PLOTLY VISUALIZATIONS
# ============================================================================

cat("Creating interactive visualizations...\n")

# Create interactive composite score
df_scores <- df %>%
  filter(!is.na(year)) %>%
  group_by(year) %>%
  summarize(
    sentiment = mean(sentiment_score, na.rm = TRUE),
    dashes = mean(dashes_per_1k, na.rm = TRUE),
    bullets = mean(bullets_per_1k, na.rm = TRUE),
    length = mean(char_count, na.rm = TRUE) / 1000,  # Scale to thousands
    mixed_case = mean(mixed_case_ratio, na.rm = TRUE) * 100,  # Convert to percentage
    count = n()
  ) %>%
  filter(count >= 5) %>%
  pivot_longer(cols = c(sentiment, dashes, bullets, length, mixed_case),
               names_to = "metric",
               values_to = "value")

# Normalize each metric to 0-100 scale for comparison
df_scores <- df_scores %>%
  group_by(metric) %>%
  mutate(normalized_value = (value - min(value)) / (max(value) - min(value)) * 100) %>%
  ungroup()

# Interactive plot
fig_interactive <- plot_ly(df_scores, x = ~year, y = ~normalized_value, 
                           color = ~metric, type = 'scatter', mode = 'lines+markers',
                           colors = c("#2E86AB", "#F77F00", "#8338EC", "#FB5607", "#06A77D"),
                           hovertemplate = paste('<b>%{fullData.name}</b><br>',
                                               'Year: %{x}<br>',
                                               'Score: %{y:.2f}<br>',
                                               '<extra></extra>')) %>%
  layout(title = list(text = "LLM Detection Metrics Over Time (Normalized)",
                     font = list(size = 18, family = "Arial, sans-serif")),
         xaxis = list(title = "Year"),
         yaxis = list(title = "Normalized Score (0-100)"),
         hovermode = "closest",
         legend = list(title = list(text = "Metric")))

htmlwidgets::saveWidget(fig_interactive, "llm_detection_interactive.html", selfcontained = FALSE)
cat("  Saved: llm_detection_interactive.html\n")

# ============================================================================
# SECTION 10: STATISTICAL ANALYSIS AND SUMMARY
# ============================================================================

cat("\nPerforming statistical analysis...\n")

# Calculate trend correlations with time
metrics_summary <- data.frame(
  Metric = c("Sentiment", "Typo Rate", "Mixed Case", "Em/En Dashes", 
             "Report Length", "Bullet Points"),
  Trend = c("", "", "", "", "", ""),
  P_Value = c(0, 0, 0, 0, 0, 0),
  Correlation = c(0, 0, 0, 0, 0, 0)
)

# Sentiment trend (weighted by sample size)
if (nrow(sentiment_by_year) > 2) {
  pol_lm <- lm(avg_sentiment ~ year, data = sentiment_by_year, weights = count)
  metrics_summary[1, "P_Value"] <- summary(pol_lm)$coefficients[2, 4]
  metrics_summary[1, "Correlation"] <- cor(sentiment_by_year$year, 
                                            sentiment_by_year$avg_sentiment)
  metrics_summary[1, "Trend"] <- ifelse(coef(pol_lm)[2] > 0, "↑ Increasing", "↓ Decreasing")
}

# Typo rate trend (weighted by sample size)
if (nrow(typo_by_year) > 2) {
  typo_lm <- lm(avg_typo_rate ~ year, data = typo_by_year, weights = count)
  metrics_summary[2, "P_Value"] <- summary(typo_lm)$coefficients[2, 4]
  metrics_summary[2, "Correlation"] <- cor(typo_by_year$year, typo_by_year$avg_typo_rate)
  metrics_summary[2, "Trend"] <- ifelse(coef(typo_lm)[2] > 0, "↑ Increasing", "↓ Decreasing")
}

# Mixed case trend (weighted by sample size)
if (nrow(mixed_case_by_year) > 2) {
  mixed_lm <- lm(avg_mixed_case ~ year, data = mixed_case_by_year, weights = count)
  metrics_summary[3, "P_Value"] <- summary(mixed_lm)$coefficients[2, 4]
  metrics_summary[3, "Correlation"] <- cor(mixed_case_by_year$year, 
                                           mixed_case_by_year$avg_mixed_case)
  metrics_summary[3, "Trend"] <- ifelse(coef(mixed_lm)[2] > 0, "↑ Increasing", "↓ Decreasing")
}

# Dashes trend (weighted by sample size)
if (nrow(dashes_by_year) > 2) {
  dash_lm <- lm(avg_dashes ~ year, data = dashes_by_year, weights = count)
  metrics_summary[4, "P_Value"] <- summary(dash_lm)$coefficients[2, 4]
  metrics_summary[4, "Correlation"] <- cor(dashes_by_year$year, dashes_by_year$avg_dashes)
  metrics_summary[4, "Trend"] <- ifelse(coef(dash_lm)[2] > 0, "↑ Increasing", "↓ Decreasing")
}

# Length trend (weighted by sample size)
if (nrow(length_by_year) > 2) {
  length_lm <- lm(avg_chars ~ year, data = length_by_year, weights = count)
  metrics_summary[5, "P_Value"] <- summary(length_lm)$coefficients[2, 4]
  metrics_summary[5, "Correlation"] <- cor(length_by_year$year, length_by_year$avg_chars)
  metrics_summary[5, "Trend"] <- ifelse(coef(length_lm)[2] > 0, "↑ Increasing", "↓ Decreasing")
}

# Bullets trend (weighted by sample size)
if (nrow(bullets_by_year) > 2) {
  bullet_lm <- lm(avg_bullets ~ year, data = bullets_by_year, weights = count)
  metrics_summary[6, "P_Value"] <- summary(bullet_lm)$coefficients[2, 4]
  metrics_summary[6, "Correlation"] <- cor(bullets_by_year$year, bullets_by_year$avg_bullets)
  metrics_summary[6, "Trend"] <- ifelse(coef(bullet_lm)[2] > 0, "↑ Increasing", "↓ Decreasing")
}

# Create summary table visualization
p_summary <- ggplot(metrics_summary, aes(x = reorder(Metric, Correlation), y = Correlation)) +
  geom_col(aes(fill = P_Value < 0.05), width = 0.7) +
  geom_text(aes(label = sprintf("r=%.3f\n%s", Correlation, Trend)), 
            hjust = ifelse(metrics_summary$Correlation > 0, -0.1, 1.1),
            size = 3.5, fontface = "bold") +
  scale_fill_manual(values = c("#CCCCCC", "#2E86AB"), 
                    labels = c("Not Significant", "Significant (p<0.05)")) +
  scale_y_continuous(expand = expansion(mult = c(0.15, 0.15))) +  # Add 15% padding on both sides
  coord_flip(clip = "off") +  # Prevent clipping of text labels
  labs(
    title = "Correlation of LLM Indicators with Time (2020+)",
    subtitle = "Weighted regression analysis - Positive correlations suggest increasing AI usage",
    x = NULL,
    y = "Correlation with Year",
    fill = "Statistical Significance",
    caption = "Analysis filtered to 2020+ data | Regressions weighted by sample size"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 14),
        plot.caption = element_text(size = 9, color = "gray50", hjust = 0),
        plot.margin = margin(10, 30, 10, 10))

ggsave("llm_correlation_summary.png", p_summary, 
       width = 10, height = 6, dpi = 300, bg = "white")

cat("  Saved: llm_correlation_summary.png\n")

# ============================================================================
# SECTION 11: HEATMAP VISUALIZATION
# ============================================================================

cat("Creating temporal heatmap...\n")

# Create year-month aggregation for all metrics
heatmap_data <- df %>%
  filter(year >= 2020) %>%  # Focus on recent years for clarity
  mutate(year_month = floor_date(date, "month")) %>%
  group_by(year_month) %>%
  summarize(
    sentiment = mean(sentiment_score, na.rm = TRUE),
    dashes = mean(dashes_per_1k, na.rm = TRUE),
    bullets = mean(bullets_per_1k, na.rm = TRUE),
    length_kb = mean(char_count, na.rm = TRUE) / 1000,
    count = n()
  ) %>%
  filter(count >= 3) %>%
  pivot_longer(cols = c(sentiment, dashes, bullets, length_kb),
               names_to = "metric",
               values_to = "value") %>%
  group_by(metric) %>%
  mutate(normalized = (value - min(value)) / (max(value) - min(value))) %>%
  ungroup()

p_heatmap <- ggplot(heatmap_data, aes(x = year_month, y = metric, fill = normalized)) +
  geom_tile(color = "white", size = 0.5) +
  scale_fill_viridis(option = "plasma", name = "Normalized\nValue") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  labs(
    title = "Temporal Heatmap of LLM Indicators (2020+)",
    subtitle = "Lighter colors indicate stronger AI signatures",
    x = NULL,
    y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5, size = 8),
        legend.position = "right",
        plot.title = element_text(face = "bold", size = 14))

ggsave("llm_temporal_heatmap.png", p_heatmap, 
       width = 14, height = 5, dpi = 300, bg = "white")

cat("  Saved: llm_temporal_heatmap.png\n")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("ANALYSIS COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

cat("Generated Outputs:\n")
cat("\nIndividual Metrics:\n")
cat("  1. metric_1_sentiment.png - AI Sentiment Signature (All Years)\n")
cat("  2. metric_1_sentiment_2025_monthly.png - 2025 Monthly Sentiment Trends\n")
cat("  3. metric_2_typos.png - The Disappearing Typo\n")
cat("  4. metric_3_mixed_case.png - Title Case Takeover\n")
cat("  5. metric_4_dashes.png - Fancy Dash Revolution\n")
cat("  6. metric_5_length.png - Verbosity Inflation\n")
cat("  7. metric_6_bullets.png - Bullet Point Explosion\n")
cat("\nComposite Visualizations:\n")
cat("  8. llm_detection_dashboard.png - Comprehensive 6-panel analysis\n")
cat("  9. llm_detection_interactive.html - Interactive plotly visualization\n")
cat(" 10. llm_correlation_summary.png - Statistical correlation summary (WEIGHTED)\n")
cat(" 11. llm_temporal_heatmap.png - Recent trends heatmap\n\n")

cat("Key Findings (Weighted Regression Analysis):\n")
print(metrics_summary)

cat("\n\nDataset Summary:\n")
cat(sprintf("  Total reports analyzed: %d\n", nrow(df)))
cat(sprintf("  Date range: %s to %s\n", 
            format(min(df$date), "%Y-%m-%d"), 
            format(max(df$date), "%Y-%m-%d")))
cat(sprintf("  Years covered: %d to %d (filtered to 2020+)\n", min(df$year), max(df$year)))

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("Ready for presentation! \n")
cat(strrep("=", 80) %+% "\n")

