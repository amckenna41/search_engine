#import required modules and dependancies
import sys
import json

#import crawl function from crawl file
from sls_scraper.crawl import crawl

#function that calls the crawl function to initiatie the spider
def scrape(event={}, context={}):
    crawl(**event)

#main function to start crawl function
if __name__ == "__main__":
    try:
        event = json.loads(sys.argv[1])
    except IndexError:
        event = {}
    scrape(event)
