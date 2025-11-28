"""
HackerOne Public Report Scraper - Fixed Version
Scrapes publicly disclosed vulnerability reports and extracts features
"""

import scrapy
from scrapy_playwright.page import PageMethod
import time
import pandas as pd
from urllib.parse import urljoin
from markdownify import markdownify as md
from bs4 import BeautifulSoup
import logging

class HackerOneSpiderHacktivity(scrapy.Spider):
    name = "hackerone_hacktivity"
    
    logger = logging.getLogger(__name__)

    custom_settings = {
        'DOWNLOAD_DELAY': 0.75,  
        'CONCURRENT_REQUESTS': 1,
        'CONCURRENT_REQUESTS_PER_DOMAIN': 1,
        'ROBOTSTXT_OBEY': False,
        'DOWNLOAD_TIMEOUT': 35, 
        'RETRY_TIMES': 2, 
        'DOWNLOAD_HANDLERS': {
            "http": "scrapy_playwright.handler.ScrapyPlaywrightDownloadHandler",
            "https": "scrapy_playwright.handler.ScrapyPlaywrightDownloadHandler",
        },
        'TWISTED_REACTOR': "twisted.internet.asyncioreactor.AsyncioSelectorReactor",
        'PLAYWRIGHT_BROWSER_TYPE': 'chromium',
        'PLAYWRIGHT_LAUNCH_OPTIONS': {
            'headless': True,
            'args': [
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--disable-blink-features=AutomationControlled',
                '--disable-web-security', 
                '--disable-features=site-per-process',  
                '--disable-background-timer-throttling',  
                '--disable-backgrounding-occluded-windows',  
                '--disable-renderer-backgrounding',
                '--memory-pressure-off',  # Prevent memory pressure
                '--max_old_space_size=4096',  # Increase memory limit
            ]
        },
        'PLAYWRIGHT_MAX_PAGES_PER_CONTEXT': 1,  # Reduced to prevent memory leaks
        'PLAYWRIGHT_CONTEXTS': {
            'default': {
                'viewport': {'width': 1920, 'height': 1080},
                'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        },
        'DEFAULT_REQUEST_HEADERS': {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
        'FEEDS': {
            'hackerone_reports_content_output.json': { 
                'format': 'json',              
                'encoding': 'utf8',
                'indent': 4,                   
                'overwrite': True
            },
            'hackerone_reports_content_output.csv': {
                'format': 'csv',
                'encoding': 'utf8',
                'fields': ['url', 'original_report'],
                'overwrite': True
            }
        },
        'AUTOTHROTTLE_ENABLED': True,
        'AUTOTHROTTLE_START_DELAY': 0.5,
        'AUTOTHROTTLE_MAX_DELAY': 10,
        'AUTOTHROTTLE_TARGET_CONCURRENCY': 2.0,
    }

    async def start(self):
        """Start method with memory optimization"""
        try:
            reports_init = pd.read_json("hackerone_reports_output.json")
            self.logger.info(f"Loaded {len(reports_init)} reports to process")
            
            for i, url in enumerate(reports_init['url']):
                # Add memory cleanup every 10 requests
                if i % 10 == 0 and i > 0:
                    self.logger.info(f"Processed {i} reports, performing memory cleanup...")
                    await self.cleanup_memory()
                
                yield scrapy.Request(
                    url=url,
                    meta={
                        'playwright': True,
                        'playwright_include_page': True,
                        'playwright_page_methods': [
                            PageMethod('wait_for_selector', 'div#report-information', timeout=15000),
                        ],
                        'playwright_page_close': True,
                        'playwright_context': 'default',  # Use shared context
                    },
                    callback=self.parse_report_page,
                    errback=self.errback_handler,
                    dont_filter=True
                )
        except Exception as e:
            self.logger.error(f"Error in start method: {e}")
    
    async def cleanup_memory(self):
        """Perform memory cleanup to prevent accumulation"""
        try:
            import gc
            gc.collect()
            self.logger.info("Memory cleanup completed")
        except Exception as e:
            self.logger.error(f"Error during memory cleanup: {e}")

    def errback_handler(self, failure):
        """Handle request failures"""
        self.logger.error(f"Request failed: {failure.request.url} - {failure.value}")

    async def scroll_to_load_all(self, page):
        """Handle infinite scroll to load all content"""
        previous_count = 0
        scroll_attempts = 0
        max_scroll_attempts = 50
        
        while scroll_attempts < max_scroll_attempts:
            try:
                # Count current items
                current_items = await page.query_selector_all('.timeline-item')
                current_count = len(current_items)
                
                # If no new items loaded after scrolling, we're done
                if current_count == previous_count and scroll_attempts > 0:
                    self.logger.info(f"No new items loaded. Stopping scroll. Total items: {current_count}")
                    break
                    
                previous_count = current_count
                
                # Scroll to bottom
                await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                
                # Wait for new content to load
                await page.wait_for_timeout(2000)
                
                scroll_attempts += 1
                self.logger.info(f"Scroll attempt {scroll_attempts}, items loaded: {current_count}")
                
            except Exception as e:
                self.logger.error(f"Error during scrolling: {e}")
                break
    
    async def get_report_content_css(self, selector):
        """Extract report content using CSS selector"""
        try:
            report_wrapper = selector.css('div#report-information div.spec-vulnerability-information div.interactive-markdown')
            if report_wrapper:
                self.logger.info("Report content found with primary selector.")
                return 1, report_wrapper[0]
            
            report_wrapper = selector.css('div.spec-full-summary-content')
            if report_wrapper:
                self.logger.info("Report content found with secondary selector.")
                return 2, report_wrapper[0]
            
            return 0, None
        except Exception as e:
            logging.error(f"Error extracting report content: {e}")
            return 0, None
        
    async def sanitize_html(self, type, text):
        """Clean and sanitize extracted text"""
        soup = BeautifulSoup(text, 'html.parser')

        match type:
            case 1:
                # Remove the extra 'menu' texts at the beginning
                extra_menu = soup.find('svg', class_='injected-svg')
                if extra_menu:
                    extra_menu.decompose()
            case 2:
                # Remove the extra 'menu' texts at the beginning
                extra_menu = soup.find('svg', class_='injected-svg')
                if extra_menu:
                    extra_menu.decompose()
            case _:
                self.logger.warning(f"Unknown report type for sanitization: {type}")
                return text
        
        # Remove code blocks
        code_blocks = soup.find_all('div', class_='interactive-markdown__code')
        self.logger.info(f"Removing {len(code_blocks)} code blocks from report content.")
        for code_block in code_blocks:
            code_block.decompose()
        
        clean_text = soup.prettify()            
        return clean_text
    
    def extract_text_optimized(self, html_content):
        """Optimized text extraction with minimal processing"""
        try:
            # Use BeautifulSoup for basic cleaning only
            soup = BeautifulSoup(html_content, 'html.parser')
            
            # Remove code blocks efficiently
            for code_block in soup.find_all('div', class_='interactive-markdown__code'):
                code_block.decompose()
            
            # Remove SVG elements
            for svg in soup.find_all('svg', class_='injected-svg'):
                svg.decompose()
            
            # Convert to markdown with minimal processing
            text = md(str(soup))
            
            # Basic cleanup
            text = text.strip()
            
            return text
            
        except Exception as e:
            self.logger.error(f"Error in text extraction: {e}")
            # Fallback to basic text extraction
            return html_content.strip()

    async def parse_report_page(self, response):
        """Parse individual report page to extract detailed content - Optimized version"""
        start_time = time.time()
        
        self.logger.info(f"Processing Report URL: {response.url}")

        page = response.meta.get('playwright_page')
        
        try:
            # Use Playwright's built-in selectors instead of loading full HTML
            report_content = None
            
            # Try primary selector first
            try:
                report_element = await page.query_selector('div#report-information div.spec-vulnerability-information div.interactive-markdown')
                if report_element:
                    report_content = await report_element.inner_html()
                    self.logger.info("Report content found with primary selector.")
            except Exception:
                pass
            
            # Try secondary selector if primary failed
            if not report_content:
                try:
                    report_element = await page.query_selector('div.spec-full-summary-content')
                    if report_element:
                        report_content = await report_element.inner_html()
                        self.logger.info("Report content found with secondary selector.")
                except Exception:
                    pass
            
            if not report_content:
                self.logger.warning(f"No report content found for {response.url}")
                return
            
            # Optimized HTML processing - do minimal parsing
            text = self.extract_text_optimized(report_content)
            
            processing_time = time.time() - start_time
            self.logger.info(f"Report processed in {processing_time:.2f}s: {response.url}")

            report_data = {
                'url': response.url,
                'original_report': text
            }
            
            yield report_data
            
        except Exception as e:
            self.logger.error(f"Error parsing report URL {response.url}: {e}")
        finally:
            # Ensure page is properly closed
            try:
                await page.close()
            except Exception:
                pass

if __name__ == "__main__":
    from scrapy.crawler import CrawlerProcess
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(name)s] %(levelname)s: %(message)s'
    )
    
    process = CrawlerProcess()
    process.crawl(HackerOneSpiderHacktivity)
    process.start()