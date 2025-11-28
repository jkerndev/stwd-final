"""
HackerOne Public Report Scraper - Fixed Version
Scrapes publicly disclosed vulnerability reports and extracts features
"""

import scrapy
from scrapy_playwright.page import PageMethod
import time
from urllib.parse import urljoin
import logging

class HackerOneSpiderHacktivity(scrapy.Spider):
    name = "hackerone_hacktivity"
    
    # Add logging
    logger = logging.getLogger(__name__)

    # Custom settings
    custom_settings = {
        'DOWNLOAD_DELAY': 0.5,
        'CONCURRENT_REQUESTS': 2,
        'CONCURRENT_REQUESTS_PER_DOMAIN': 2,
        'ROBOTSTXT_OBEY': False,
        'DOWNLOAD_TIMEOUT': 30,
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
            ]
        },
        'PLAYWRIGHT_MAX_PAGES_PER_CONTEXT': 3, 
        'DEFAULT_REQUEST_HEADERS': {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
        'FEEDS': {
            'hackerone_reports_output.json': { 
                'format': 'json',              
                'encoding': 'utf8',
                'indent': 4,                   
                'overwrite': True
            }
        },
        'AUTOTHROTTLE_ENABLED': True,
        'AUTOTHROTTLE_START_DELAY': 0.5,
        'AUTOTHROTTLE_MAX_DELAY': 10,
        'AUTOTHROTTLE_TARGET_CONCURRENCY': 2.0,
    }

    async def start(self):
        teams = ['curl']
        
        for team in teams:
            url = f'https://hackerone.com/{team}/hacktivity?type=team'
            yield scrapy.Request(
                url=url,
                meta={
                    'playwright': True,
                    'playwright_include_page': True,
                    'playwright_page_methods': [
                        PageMethod('wait_for_selector', 'div[data-testid="hacktivity-item"]', timeout=15000),
                    ],
                    'team': team,
                    'playwright_page_close': True,
                },
                callback=self.parse_hacktivity_page,
                errback=self.errback_handler,
                dont_filter=True
            )

    def errback_handler(self, failure):
        """Handle request failures"""
        self.logger.error(f"Request failed: {failure.request.url} - {failure.value}")

    async def parse_hacktivity_page(self, response):
        """Parse the main hacktivity page and handle infinite scroll"""
        
        page = response.meta.get('playwright_page')
        if not page:
            self.logger.error("No playwright page available")
            return
            
        team = response.meta['team']
        
        try:
            # Handle infinite scroll to load all posts
            await self.scroll_to_load_all(page)
            
            # Get all hacktivity items
            page_html = await page.content()
            selector = scrapy.Selector(text=page_html)
            
            self.logger.info(f"Found hacktivity items for team {team}")

            hacktivity_items = selector.css('div[data-testid="hacktivity-item"]')
            
            for item in hacktivity_items:
                # Extract basic info from the hacktivity item
                title = item.css('div[data-testid="report-title"] span.line-clamp-2::text').get()
                href = item.css('.md\:text-md a::attr(href)').get()
                
                report_url = urljoin("https://hackerone.com", href)

                self.logger.info(f"Processing report: {title} URL: {report_url}")
                
                # Extract metadata
                metadata = await self.extract_hacktivity_metadata_simple(item, title)

                report_overview = {
                    'team': team,
                    'title': title,
                    'url': report_url,
                    'hacktivity_metadata': metadata,
                }

                yield report_overview
                
        except Exception as e:
            self.logger.error(f"Error in parse_hacktivity_page: {e}")
        finally:
            if page and not page.is_closed():
                await page.close()
    
    async def parse_report_page(self, response):
        """Parse individual report page to extract detailed content"""

        start_time = time.time()
        
        team = response.meta['team']
        title = response.meta['title']
        hacktivity_metadata = response.meta['hacktivity_metadata']
        
        # Extract report content
        report_data = {
            'team': team,
            'title': title,
            'url': response.url,
            'hacktivity_metadata': hacktivity_metadata
        }

        self.logger.info(f"Processing report page: {title} Report URL: {response.url}")
        
        try:
            # Extract main report content
            #print(f"Debugging: {response.text}")
            report_wrapper = response.css('#report-information')[0]
            if report_wrapper:
                
                # Extract original report content
                original_report = report_wrapper.css('.interactive-markdown::text').get()
                report_data['original_report'] = await original_report.inner_text()
                #print(f"Original Report: {report_data['original_report'][:100]}...")
                    
        except Exception as e:
            self.logger.error(f"Error parsing report page {title} at URL {response.url}: {e}")

        processing_time = time.time() - start_time
        self.logger.info(f"Report processed in {processing_time:.2f}s: {title}")
        
        yield report_data

    async def scroll_to_load_all(self, page):
        """Handle infinite scroll to load all content"""
        previous_count = 0
        scroll_attempts = 0
        max_scroll_attempts = 100
        
        while scroll_attempts < max_scroll_attempts:
            try:
                # Count current items
                current_items = await page.query_selector_all('div[data-testid="hacktivity-item"]')
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

    async def extract_hacktivity_metadata_simple(self, item: scrapy.Selector, title):
        """Extract metadata from hacktivity item with better error handling"""
        metadata = {}
        
        try:
            # Extract bounty
            try:
                bounty_element = item.css('.spec-amount-in-currency span::text').get()
                if bounty_element:
                    metadata['bounty'] = bounty_element
            except:
                pass
            
            # Extract severity
            try:
                severity_element = item.css('span[data-testid="report-severity"] span span span span span::text').get()
                if severity_element:
                    metadata['severity'] = severity_element
            except:
                pass
            
            # Extract date
            try:
                date_element = item.css('span[title]::attr(title)').get()
                if date_element:
                    metadata['date'] = date_element
            except:
                pass
                
        except Exception as e:
            self.logger.error(f"Error extracting metadata for {title}: {e}")
            
        return metadata

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