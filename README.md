# search_engine
Repository for QSE (Queen's Search Engine) - CS Project for Cloud Computing module, creating a functioning search engine with back-end and front-end funtionality. This repository holds all relevant code for the front-end, back-end and Terraform deployment scripts which were formally placed in their own individual repositories.

Objective:
The objective of this project was to create a functional search engine, hosted on the Cloud. The search engine incorporated a user-facing front-end offering the user a GUI and search bar upon which to enter their search term. This front-end would then interact with a back-end serach feature that would search through the back-end data store and return a result back to the user. The data store would contain indexed data which was pulled from a selection of web pages using a web scraper. In addition to the data store for the search results, there was also required to be an ads data store that would store similar indexed advertisement data that would be displayed in the front-end alongside the search results.

Web-crawler:
The web crawler or spider indexer for the QSE was created in Python using the extensible and versatile framework Scrapy. A selection of wikipedia pages were used for scraping. The output from the scraped data was indexed and placed into a DynamoDB table on AWS programmatically using the Boto3 AWS Python library. 

Front-end:
The front-end for the search engine was hosted in an S3 bucket due to its static web hosting capability. 

Search:

Back-end:

Deployment Scipts:

Hosting:
