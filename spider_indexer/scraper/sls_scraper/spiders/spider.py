
#import required modules and dependancies
import scrapy
from scrapy.loader import ItemLoader
from scrapy.selector import Selector
import boto3        #AWS's Python SDK

#create instance of DynamoDB service using boto3
dynamodb = boto3.resource('dynamodb', region_name='eu-west-1')

#create variable holding instance of table
table = dynamodb.Table('spider')

#class containing spider
class CrawlerSpider(scrapy.Spider):
    name = 'spider'

    #start_urls is array holding all URL's that spider will crawl
    #to test - try putting some new wikipedia country pages in the array
    start_urls = ['https://en.wikipedia.org/wiki/Poland', 'https://en.wikipedia.org/wiki/China', 'https://en.wikipedia.org/wiki/India']
    def parse(self, response):
        str1 = " "
        title_2 = response.css("title::text")[0].extract()          #extract title of page
        h1 = response.css('h1::text')[0].extract()                  #extract H1 of page
        h2 = response.css('h2::text')[0].extract()                  #extract H2 of page
        text = response.css("p::text").extract()                    #extract remaining text of page
        list_to_str = str1.join(text)
        strip_text = list_to_str.strip()                            #remove whitespace
        final_text = strip_text[59:]                                #remove leading characters which contain unwanted metadata

        #put_item function part of boto3 library, allows for scraped items to be placed in dynamodb table
        table.put_item(
             Item={
                 'Title': h1,
                 'Heading1':h1,
                 'Heading2':h2,
                 'URLText': final_text
                    }
               )

        #yield prints the scraped output to terminal 
        yield {
            'Title': title_2,
            'Heading1':h1,
            'Heading2':h2,
            'URLText': final_text
            }
