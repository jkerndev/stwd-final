# ============================================================================
# Death by a Thousand Slops - Shiny Scrollytelling Application
# ============================================================================

library(shiny)
library(htmltools)

# ============================================================================
# UI
# ============================================================================

ui <- fluidPage(
  
  # Custom CSS and JavaScript
  tags$head(
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;900&display=swap"),
    tags$script(src = "https://unpkg.com/intersection-observer@0.12.0/intersection-observer.js"),
    tags$script(src = "https://unpkg.com/scrollama"),
    
    tags$style(HTML("
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }
      
      .center {
        display: block;
        margin-left: auto;
        margin-right: auto;
        width: 50%;
      }
      
      body {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        background-color: #0a0e27;
        color: #e8eaf6;
        line-height: 1.6;
        overflow-x: hidden;
      }
      
      /* Remove Shiny container padding */
      .container-fluid {
        padding: 0 !important;
        max-width: 100% !important;
      }
      
      /* Hero Section */
      #hero {
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        text-align: center;
        background: linear-gradient(135deg, #050814 0%, #0a0e27 100%);
        padding: 4rem 2rem;
      }
      
      .hero-title {
        font-size: clamp(2.5rem, 8vw, 5.5rem);
        font-weight: 900;
        text-transform: uppercase;
        letter-spacing: -0.02em;
        margin-bottom: 1.5rem;
        background: linear-gradient(135deg, #2E86AB, #8338EC, #F77F00);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        line-height: 1.1;
      }
      
      .hero-subtitle {
        font-size: clamp(1.2rem, 3vw, 2rem);
        color: #9fa8da;
        margin-bottom: 2rem;
        font-weight: 400;
      }
      
      .hero-meta {
        font-size: 1rem;
        color: #9fa8da;
        opacity: 0.8;
      }
      
      .scroll-hint {
        margin-top: 4rem;
        font-size: 0.9rem;
        color: #9fa8da;
        opacity: 0.6;
        animation: float 3s ease-in-out infinite;
      }
      
      @keyframes float {
        0%, 100% { transform: translateY(0); }
        50% { transform: translateY(10px); }
      }
      
      /* Narrative Section */
      .narrative-section {
        max-width: 900px;
        margin: 6rem auto;
        padding: 3rem 2rem;
      }
      
      .section-title {
        font-size: clamp(2.5rem, 5vw, 4rem);
        font-weight: 700;
        margin-bottom: 3rem;
        color: #2E86AB;
        text-align: center;
      }
      
      .large-text {
        font-size: clamp(1.3rem, 2.5vw, 1.9rem);
        line-height: 1.6;
        margin-bottom: 2.5rem;
      }
      
      .highlight { color: #2E86AB; font-weight: 600; }
      .highlight-red { color: #E63946; font-weight: 700; }
      .highlight-ai { color: #8338EC; font-weight: 600; }
      
      /* Stat Boxes */
      .stat-box {
        background: linear-gradient(135deg, rgba(46, 134, 171, 0.15), rgba(131, 56, 236, 0.15));
        border: 2px solid rgba(46, 134, 171, 0.4);
        border-radius: 20px;
        padding: 3rem 2rem;
        text-align: center;
        margin: 3rem auto;
        max-width: 500px;
        transition: transform 0.3s ease;
      }
      
      .stat-box:hover {
        transform: scale(1.05);
      }
      
      .stat-number {
        font-size: clamp(4rem, 10vw, 7rem);
        font-weight: 900;
        color: #2E86AB;
        line-height: 1;
        margin-bottom: 1rem;
      }
      
      .stat-label {
        font-size: clamp(1.1rem, 2vw, 1.6rem);
        color: #9fa8da;
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }
      
      /* Quote */
      .quote-box {
        border-left: 4px solid #2E86AB;
        padding-left: 2rem;
        margin: 4rem 0;
        font-style: italic;
      }
      
      .quote-text {
        font-size: clamp(1.3rem, 2.5vw, 2rem);
        line-height: 1.7;
        margin-bottom: 1rem;
      }
      
      .quote-author {
        color: #9fa8da;
        font-style: normal;
        font-size: 1.1rem;
      }
      
      /* Scrollytelling Section */
      #scrolly {
        position: relative;
        padding: 0;
      }
      
      .scrolly-overlay {
        position: relative;
        pointer-events: none;
      }
      
      article {
        position: relative;
        padding: 0 1rem;
        max-width: 40rem;
        margin: 0 auto;
      }
      
      figure {
        position: -webkit-sticky;
        position: sticky;
        left: 0;
        width: 100%;
        margin: 0;
        -webkit-transform: translate3d(0, 0, 0);
        -moz-transform: translate3d(0, 0, 0);
        transform: translate3d(0, 0, 0);
        z-index: 0;
      }
      
      figure img {
        width: 90%;
        max-width: 1200px;
        margin: 0 auto;
        display: block;
        border-radius: 12px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6);
        transition: opacity 0.3s ease;
      }
      
      .step {
        margin: 0 auto 60vh auto;
        padding: 2rem;
        background: rgba(10, 14, 39, 0.95);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 16px;
        backdrop-filter: blur(20px);
        pointer-events: auto;
        opacity: 0.3;
        transition: opacity 0.6s ease;
      }
      
      .step:last-child {
        margin-bottom: 0;
      }
      
      .step.is-active {
        opacity: 1;
      }
      
      .step h3 {
        font-size: clamp(1.8rem, 4vw, 2.5rem);
        color: #2E86AB;
        margin-bottom: 1rem;
      }
      
      .step p {
        font-size: clamp(1.1rem, 2vw, 1.4rem);
        line-height: 1.6;
        margin-bottom: 1rem;
        color: #e8eaf6;
      }
      
      .finding-box {
        background: linear-gradient(135deg, rgba(46, 134, 171, 0.2), rgba(6, 167, 125, 0.2));
        border: 2px solid #06A77D;
        border-radius: 12px;
        padding: 1.5rem;
        margin-top: 1.5rem;
      }
      
      .finding-box strong {
        color: #06A77D;
      }
      
      /* Metrics Grid */
      .metrics-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 2rem;
        margin: 4rem 0;
      }
      
      .metric-card {
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 16px;
        padding: 2.5rem 2rem;
        text-align: center;
        transition: all 0.3s ease;
      }
      
      .metric-card:hover {
        transform: translateY(-5px);
        border-color: #2E86AB;
      }
      
      .metric-icon {
        font-size: 4rem;
        display: block;
        margin-bottom: 1rem;
      }
      
      .metric-card h3 {
        font-size: 1.5rem;
        margin: 1rem 0 0.5rem;
        color: #e8eaf6;
      }
      
      .metric-card p {
        font-size: 1rem;
        color: #9fa8da;
        line-height: 1.5;
      }
      
      /* Verdict Grid */
      .verdict-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: 2rem;
        margin: 4rem 0;
      }
      
      .verdict-card {
        background: rgba(255, 255, 255, 0.05);
        border: 2px solid rgba(255, 255, 255, 0.15);
        border-radius: 16px;
        padding: 2rem;
        text-align: center;
        transition: transform 0.3s ease;
      }
      
      .verdict-card:hover {
        transform: scale(1.05);
      }
      
      .metric-name {
        font-size: 1.4rem;
        font-weight: 600;
        margin-bottom: 1rem;
        color: #e8eaf6;
      }
      
      .trend {
        font-size: 2rem;
        font-weight: 700;
      }
      
      .trend-up { color: #E63946; }
      .trend-down { color: #06A77D; }
      .trend-down2 { color: #E63946; }
      
      /* Cost Box */
      .cost-box {
        background: linear-gradient(135deg, rgba(230, 57, 70, 0.15), rgba(251, 86, 7, 0.15));
        border: 2px solid rgba(230, 57, 70, 0.4);
        border-radius: 20px;
        padding: 3rem 2rem;
        text-align: center;
        margin: 3rem auto;
        max-width: 600px;
      }
      
      .cost-title {
        font-size: clamp(2rem, 5vw, 3rem);
        color: #E63946;
        margin-bottom: 1rem;
        font-weight: 700;
      }
      
      .cost-desc {
        font-size: clamp(1.1rem, 2vw, 1.4rem);
        color: #9fa8da;
      }
      
      /* Conclusion List */
      .conclusion-list {
        list-style: none;
        padding: 2rem 0;
        max-width: 700px;
        margin: 2rem auto;
      }
      
      .conclusion-list li {
        font-size: 1.3rem;
        padding: 1rem 0 1rem 2.5rem;
        position: relative;
        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
      }
      
      .conclusion-list li::before {
        content: '→';
        position: absolute;
        left: 0;
        color: #2E86AB;
        font-weight: 700;
        font-size: 1.8rem;
      }
      
      .final-thought {
        font-size: clamp(1.5rem, 3vw, 2.2rem);
        font-weight: 600;
        text-align: center;
        margin: 4rem auto;
        line-height: 1.6;
        max-width: 800px;
      }
      
      /* Dark backgrounds */
      .dark-bg {
        background: linear-gradient(135deg, #050814 0%, #1a1d3e 100%);
        padding: 4rem 2rem;
      }
      
      .divider {
        height: 2px;
        background: linear-gradient(90deg, transparent, rgba(46, 134, 171, 0.5), transparent);
        margin: 4rem 0;
        border: none;
      }
      
      /* Credits */
      .credits {
        border-top: 1px solid rgba(255, 255, 255, 0.1);
        padding: 3rem 2rem;
        margin-top: 4rem;
        text-align: center;
        color: #9fa8da;
      }
      
      .credits h3 {
        color: #2E86AB;
        margin-bottom: 1.5rem;
      }
      
      .credits a {
        color: #2E86AB;
        text-decoration: none;
      }
      
      .credits a:hover {
        text-decoration: underline;
      }
      
      /* Summary Section */
      .summary-viz {
        max-width: 1200px;
        margin: 4rem auto;
        padding: 2rem;
      }
      
      .summary-viz img {
        width: 100%;
        border-radius: 12px;
        box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
        margin: 2rem 0;
      }
      
      .viz-caption {
        font-size: 1.1rem;
        color: #9fa8da;
        text-align: center;
        margin-top: 1rem;
        font-style: italic;
      }
      
      /* Responsive */
      @media (max-width: 768px) {
        .metrics-grid,
        .verdict-grid {
          grid-template-columns: 1fr;
        }
        
        figure {
          top: 5vh;
        }
      }
      
      /* Desktop layout for scrollytelling */
      @media (min-width: 840px) {
        figure {
          top: 10vh;
          height: 80vh;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        
        .step {
          width: 30rem;
        }
      }
    "))
  ),
  
  # Hero Section
  div(id = "hero",
    h1(class = "hero-title", "Death by a Thousand Slops"),
    p(class = "hero-subtitle", "How AI is drowning open source in perfectly polite garbage"),
    p(class = "hero-meta", "A data-driven investigation inspired by Daniel Stenberg's curl project"),
    p(class = "scroll-hint", "↓ Scroll to investigate ↓")
  ),
  
  tags$hr(class = "divider"),
  
  # Problem Section
  div(class = "narrative-section",
    h2(class = "section-title", "The Slop Problem"),
    p(class = "large-text", "In July 2025, Daniel Stenberg, creator of", tags$strong("curl"),", published a desperate blog post."),
    img(src = "daniel_stenberg.jpg", class="center", style="width:400px;height:400px"),
    p(class = "large-text", HTML("<br>His team was drowning in <span class='highlight'>AI-generated security reports</span>.")),
    
    tags$hr(style = "border: none; height: 1px; background: rgba(255,255,255,0.1); margin: 3rem 0;"),
    
    h3(style = "font-size: 2rem; color: #2E86AB; margin-bottom: 1.5rem;", "Why This Matters"),
    p(class = "large-text", HTML("curl isn't just another project. It's <span class='highlight'>infrastructure</span>.")),
    p(class = "large-text", HTML("With <span class='highlight'>over 20 billion installations</span>, curl is used in virtually every connected device on Earth:")),
    
    tags$ul(style = "font-size: 1.4rem; line-height: 2; margin: 2rem 0; list-style-position: inside;",
      tags$li("Every smartphone (iOS, Android)"),
      tags$li("Your car's infotainment system"),
      tags$li("Smart TVs and IoT devices"),
      tags$li("Banking systems and medical devices"),
      tags$li("NASA's Mars rovers")
    ),
    
    p(class = "large-text", HTML("When curl has a security vulnerability, <span class='highlight-red'>billions of devices</span> are at risk.")),
    p(class = "large-text", HTML("So when maintainers report being overwhelmed by <span class='highlight-ai'>AI-generated noise</span>, it's not just an annoyance—it's a threat to global infrastructure.")),
    
    tags$hr(style = "border: none; height: 1px; background: rgba(255,255,255,0.1); margin: 3rem 0;"),
    
    div(class = "stat-box",
      div(class = "stat-number", "20%"),
      div(class = "stat-label", "of all reports were AI slop")
    ),
    
    div(class = "stat-box",
      div(class = "stat-number", "5%"),
      div(class = "stat-label", "were actual vulnerabilities")
    ),
    
    p(class = "large-text", HTML("The valid-rate had <span class='highlight-red'>decreased significantly</span> compared to previous years.")),
    
    div(class = "quote-box",
      p(class = "quote-text", '"We need to reduce the amount of sand in the machine. We must do something to drastically reduce the temptation for users to submit low quality reports."'),
      p(class = "quote-author", "— Daniel Stenberg, curl maintainer")
    )
  ),
  
  tags$hr(class = "divider"),
  
  # Question
  div(class = "dark-bg",
    h2(style = "font-size: clamp(2.5rem, 6vw, 4.5rem); color: #2E86AB; text-align: center; margin-bottom: 2rem;", 
       "Can we see this trend in the data?"),
    p(style = "font-size: clamp(1.2rem, 3vw, 1.8rem); color: #9fa8da; text-align: center;", 
      "An analysis of HackerOne public security reports")
  ),
  
  tags$hr(class = "divider"),
  
  # Methodology
  div(class = "narrative-section",
    h2(class = "section-title", "The Investigation"),
    p(class = "large-text", style = "text-align: center;", 
      HTML("We analyzed <span class='highlight'>HackerOne public reports</span> from 2020–2024.")),
    p(class = "large-text", style = "text-align: center; margin-bottom: 4rem;", 
      HTML("Looking for six linguistic fingerprints that separate <span class='highlight'>human hackers</span> from <span class='highlight-ai'>AI assistants</span>.")),
    
    div(class = "metrics-grid",
      div(class = "metric-card",
        span(class = "metric-icon", "😊"),
        h3("Sentiment"),
        p("LLMs are trained to be relentlessly positive and cheerful")
      ),
      div(class = "metric-card",
        span(class = "metric-icon", "✨"),
        h3("Perfect Grammar"),
        p("Typos vanish when AI writes")
      ),
      div(class = "metric-card",
        span(class = "metric-icon", "🔤"),
        h3("Title Case"),
        p("Proper Capitalization Everywhere")
      ),
      div(class = "metric-card",
        span(class = "metric-icon", "—"),
        h3("Fancy Dashes"),
        p("Em dashes nobody types manually")
      ),
      div(class = "metric-card",
        span(class = "metric-icon", "📝"),
        h3("Verbosity"),
        p("AI never met a paragraph it couldn't expand")
      ),
      div(class = "metric-card",
        span(class = "metric-icon", "•"),
        h3("Bullet Points"),
        p("Lists, lists everywhere")
      )
    )
  ),
  
  tags$hr(class = "divider"),
  
  # Scrollytelling sections for each metric
  lapply(1:6, function(i) {
    metric_info <- list(
      list(title = "Metric #1: The Sentiment Shift", 
           img = "metric_1_sentiment.png",
           steps = list(
             list(title = "Sentiment Analysis", 
                  text = 'We analyzed the emotional tone of reports using sentence-level sentiment scoring.',
                  img = "metric_1_sentiment.png"),
             list(title = "The Declining Trend", 
                  text = HTML("From 2020-2024, sentiment became <span class='highlight-red'>increasingly negative</span>. Hackers were frustrated, terse, direct."),
                  img = "metric_1_sentiment.png"),
             list(title = "Then Came 2025", 
                  text = HTML("But in 2025, something changed. Sentiment suddenly reversed course, becoming <span class='highlight-ai'>more positive</span>."),
                  img = "metric_1_sentiment_2025_monthly.png"),
             list(title = "The AI Signature", 
                  text = HTML("<div class='finding-box'><p><strong>Finding:</strong> The 2025 reversal toward positive sentiment is a classic AI signature—LLMs are trained to be relentlessly optimistic and polite.</p></div>"),
                  img = "metric_1_sentiment_2025_monthly.png")
           )),
      list(title = "Metric #2: The Disappearing Typo", 
           img = "metric_2_typos.png",
           steps = list(
             list(title = "Spell Checking", 
                  text = "We used dictionary-based spell checking to detect misspellings."),
             list(title = "Human Nature", 
                  text = HTML("Humans make typos. <span class='highlight'>It's natural.</span>")),
             list(title = "AI Perfection", 
                  text = HTML("AI? <span class='highlight-ai'>Perfect grammar, every time.</span>")),
             list(title = "The Finding", 
                  text = HTML("<div class='finding-box'><p><strong>Finding:</strong> Spelling errors are declining as reports get more 'perfect.'</p></div>"))
           )),
      list(title = "Metric #3: Title Case Takeover", 
           img = "metric_3_mixed_case.png",
           steps = list(
             list(title = "Capitalization Patterns", 
                  text = "Detecting sentences with Proper Capitalization patterns."),
             list(title = "Internet Culture", 
                  text = HTML("internet denizens prefer <span class='highlight'>lowercase chaos</span>.")),
             list(title = "AI Formality", 
                  text = HTML("LLMs love <span class='highlight-ai'>Proper Grammar Rules</span>.")),
             list(title = "The Finding", 
                  text = HTML("<div class='finding-box'><p><strong>Finding:</strong> Title case usage is increasing over time.</p></div>"))
           )),
      list(title = "Metric #4: The Fancy Dash Revolution", 
           img = "metric_4_dashes.png",
           steps = list(
             list(title = "Professional Punctuation", 
                  text = "Counting em dashes (—) and en dashes (–)."),
             list(title = "Quick Quiz", 
                  text = HTML("Quick: how do you type an em dash?<br><em style='color: #9fa8da;'>(You probably don't know.)</em>")),
             list(title = "Human vs AI", 
                  text = HTML("Humans use <span class='highlight'>hyphens</span>. LLMs use <span class='highlight-ai'>proper typography</span>—like this.")),
             list(title = "The Finding", 
                  text = HTML("<div class='finding-box'><p><strong>Finding:</strong> Professional punctuation usage is skyrocketing.</p></div>"))
           )),
      list(title = "Metric #5: Verbosity Inflation", 
           img = "metric_5_length.png",
           steps = list(
             list(title = "Character Counting", 
                  text = "Measuring average character count per report."),
             list(title = "Human Brevity", 
                  text = HTML("Humans write <span class='highlight'>concise reports</span>. They want to get to the point.")),
             list(title = "AI Elaboration", 
                  text = HTML("AI <span class='highlight-ai'>never stops explaining</span>. It will elaborate on every detail...")),
             list(title = "The Finding", 
                  text = HTML("<div class='finding-box'><p><strong>Finding:</strong> Reports are getting significantly longer over time.</p></div>"))
           )),
      list(title = "Metric #6: The Bullet Point Explosion", 
           img = "metric_6_bullets.png",
           steps = list(
             list(title = "Structured Formatting", 
                  text = "Detecting lists, bullet points, and structured formatting."),
             list(title = "Human Writing", 
                  text = HTML("Human writing looks like <span class='highlight'>stream of consciousness</span>.")),
             list(title = "AI Formatting", 
                  text = HTML("AI output looks like <span class='highlight-ai'>PowerPoint slides</span>: • Perfect structure • Numbered lists • Bullets everywhere")),
             list(title = "The Finding", 
                  text = HTML("<div class='finding-box'><p><strong>Finding:</strong> Structured list usage has exploded.</p></div>"))
           ))
    )[[i]]
    
    tagList(
      div(id = paste0("scrolly", i), class = "scrolly-section",
        tags$figure(
          tags$img(src = metric_info$img, alt = metric_info$title)
        ),
        tags$article(
          h2(class = "section-title", style = "margin-bottom: 100vh;", metric_info$title),
          lapply(metric_info$steps, function(step) {
            div(class = "step", 
                `data-step` = step$title,
                `data-img` = if (!is.null(step$img)) step$img else NULL,
              if (!is.null(step$title) && step$title != "The Finding") h3(step$title),
              p(step$text)
            )
          })
        )
      ),
      tags$hr(class = "divider")
    )
  }),
  
  tags$hr(class = "divider"),
  
  # Comprehensive Summary Section
  div(class = "narrative-section",
    h2(class = "section-title", "The Complete Picture"),
    p(class = "large-text", style = "text-align: center;", 
      HTML("Six metrics. One unmistakable pattern.")),
    
    div(class = "summary-viz",
      h3(style = "font-size: 2.2rem; color: #2E86AB; margin: 3rem 0 2rem; text-align: center;", 
         "Statistical Evidence: Correlation Analysis"),
      tags$img(src = "llm_correlation_summary.png", alt = "LLM Indicator Correlations"),
      p(class = "viz-caption", 
        "Weighted regression analysis showing correlation between each metric and time. Report length (r=0.797) and declining sentiment (r=-0.914) show the strongest signals.")
    ),
    
    div(class = "summary-viz",
      h3(style = "font-size: 2.2rem; color: #2E86AB; margin: 3rem 0 2rem; text-align: center;", 
         "All Metrics Over Time"),
      tags$img(src = "llm_detection_dashboard.png", alt = "Multi-metric Detection Dashboard"),
      p(class = "viz-caption", 
        "Complete temporal analysis across all six indicators. Notice how most metrics converge toward AI-like patterns in 2024-2025.")
    ),
    
    p(class = "large-text", style = "text-align: center; margin-top: 4rem;", 
      HTML("Every angle of analysis points to the same conclusion: <span class='highlight-ai'>AI is fundamentally changing how security reports are written.</span>"))
  ),
  
  tags$hr(class = "divider"),
  
  # Verdict
  div(class = "dark-bg",
    div(class = "narrative-section",
      h2(style = "font-size: clamp(3rem, 6vw, 5rem); background: linear-gradient(135deg, #2E86AB, #8338EC, #F77F00); -webkit-background-clip: text; -webkit-text-fill-color: transparent; text-align: center; margin-bottom: 3rem; font-weight: 900;", 
         "The Verdict"),
      
      div(class = "verdict-grid",
        div(class = "verdict-card",
          div(class = "metric-name", "Sentiment"),
          div(class = "trend trend-down", "↓ Declining"),
          p(style = "margin-top: 1rem; font-size: 0.9rem; color: #9fa8da;", "Then ↑ 2025 reversal")
        ),
        div(class = "verdict-card",
          div(class = "metric-name", "Perfect Grammar"),
          div(class = "trend trend-down2", "↓ Fewer Typos")
        ),
        div(class = "verdict-card",
          div(class = "metric-name", "Title Case"),
          div(class = "trend trend-up", "↑ Increasing")
        ),
        div(class = "verdict-card",
          div(class = "metric-name", "Fancy Dashes"),
          div(class = "trend trend-up", "↑ Increasing")
        ),
        div(class = "verdict-card",
          div(class = "metric-name", "Report Length"),
          div(class = "trend trend-up", "↑ Increasing")
        ),
        div(class = "verdict-card",
          div(class = "metric-name", "Bullet Points"),
          div(class = "trend trend-up", "↑ Increasing")
        )
      ),
      
      p(style = "font-size: 1.8rem; color: #9fa8da; text-align: center; margin: 4rem 0 2rem;", 
        "All six metrics more or less point to the same conclusion:"),
      
      h3(style = "font-size: clamp(2.5rem, 5vw, 3.5rem); font-weight: 700; color: #E63946; text-align: center;", 
         "AI is taking over security reports")
    )
  ),
  
  tags$hr(class = "divider"),
  
  # The Cost
  div(class = "narrative-section",
    h2(class = "section-title", "The Real Cost"),
    p(class = "large-text", style = "text-align: center;", "This isn't just about statistics."),
    p(class = "large-text", style = "text-align: center;", 
      HTML("It's about <span class='highlight'>human exhaustion</span>.")),
    
    div(class = "cost-box",
      div(class = "cost-title", "7 team members"),
      div(class = "cost-desc", "Each report reviewed by 3-4 people")
    ),
    
    div(class = "cost-box",
      div(class = "cost-title", "30 minutes to 3 hours"),
      div(class = "cost-desc", "Per report, per reviewer")
    ),
    
    div(class = "cost-box",
      div(class = "cost-title", "8 reports in one week"),
      div(class = "cost-desc", "All of them junk")
    ),
    
    div(class = "quote-box",
      p(class = "quote-text", '"They might only have three hours per week for curl. Not to mention the emotional toll it takes to deal with these mind-numbing stupidities."'),
      p(class = "quote-author", "— Daniel Stenberg")
    )
  ),
  
  tags$hr(class = "divider"),
  
  # Conclusion
  div(class = "narrative-section",
    h2(class = "section-title", "What Now?"),
    p(class = "large-text", style = "text-align: center; margin-bottom: 3rem;", 
      "Open source maintainers are considering drastic measures:"),
    
    tags$ul(class = "conclusion-list",
      tags$li("Dropping bug bounty rewards entirely"),
      tags$li("Requiring upfront payment for submissions"),
      tags$li("Implementing reputation gates"),
      tags$li("Demanding proof-of-concept videos")
    ),
    
    p(class = "final-thought", 
      HTML("The AI gold rush is forcing us to choose between <strong style='color: #2E86AB;'>openness</strong> and <strong style='color: #E63946;'>sanity</strong>.")),
    
    p(class = "final-thought", style = "font-size: clamp(1.8rem, 4vw, 2.5rem); color: #E63946;", 
      "And the slop keeps coming.")
  ),
  
  tags$hr(class = "divider"),
  
  # Credits
  div(class = "credits",
    h3("Credits & Methodology"),
    p(HTML("<strong>Data Source:</strong> HackerOne public reports (2020-2024)")),
    p(HTML("<strong>Analysis:</strong> R with tidyverse, ggplot2, sentimentr, hunspell")),
    p(HTML('<strong>Inspiration:</strong> <a href="https://daniel.haxx.se/blog/2025/07/14/death-by-a-thousand-slops/" target="_blank">Daniel Stenberg\'s "Death by a thousand slops"</a>')),
    p(HTML("<strong>Scrollytelling:</strong> Built with Shiny.")),
    p(style = "margin-top: 2rem; font-style: italic; opacity: 0.7;", 
      "An investigation into the AI-fication of security reports")
  ),
  
  # Scrollama JavaScript
  tags$script(HTML("
    // Initialize scrollama for each metric section
    for (let i = 1; i <= 6; i++) {
      const scroller = scrollama();
      const figureImg = document.querySelector('#scrolly' + i + ' figure img');
      
      scroller
        .setup({
          step: '#scrolly' + i + ' .step',
          offset: 0.5,
          debug: false
        })
        .onStepEnter(response => {
          response.element.classList.add('is-active');
          
          // Change image if data-img attribute exists
          const newImg = response.element.getAttribute('data-img');
          if (newImg && figureImg) {
            const currentSrc = figureImg.src.split('/').pop();
            if (currentSrc !== newImg) {
              // Smooth transition
              figureImg.style.opacity = '0';
              setTimeout(() => {
                figureImg.src = newImg;
                figureImg.style.opacity = '1';
              }, 300);
            }
          }
        })
        .onStepExit(response => {
          response.element.classList.remove('is-active');
        });
      
      window.addEventListener('resize', scroller.resize);
    }
    
    // Initialize scrollama for 2025 monthly section
    const scroller2025 = scrollama();
    scroller2025
      .setup({
        step: '#scrolly-2025 .step',
        offset: 0.5,
        debug: false
      })
      .onStepEnter(response => {
        response.element.classList.add('is-active');
      })
      .onStepExit(response => {
        response.element.classList.remove('is-active');
      });
    window.addEventListener('resize', scroller2025.resize);
  "))
)

# ============================================================================
# Server
# ============================================================================

server <- function(input, output, session) {}

# ============================================================================
# Run App
# ============================================================================

shinyApp(ui = ui, server = server)
