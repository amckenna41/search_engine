# search_engine
Repository for QSE (Queen's Search Engine) - CS Project for Cloud Computing module, creating a functioning search engine with back-end and front-end funtionality. This repository holds all relevant code for the front-end, back-end and Terraform deployment scripts which were formally placed in their own individual repositories.

Objective:
The objective of this project was to create a functional search engine, hosted on the Cloud. The search engine incorporated a user-facing front-end offering the user a GUI and search bar upon which to enter their search term. This front-end would then interact with a back-end serach feature that would search through the back-end data store and return a result back to the user. The data store would contain indexed data which was pulled from a selection of web pages using a web scraper. In addition to the data store for the search results, there was also required to be an ads data store that would store similar indexed advertisement data that would be displayed in the front-end alongside the search results.

Web-crawler:
The web crawler or spider indexer for the QSE was created in Python using the extensible and versatile framework Scrapy. A selection of wikipedia pages were used for scraping. The output from the scraped data was indexed and placed into a DynamoDB table on AWS programmatically using the Boto3 AWS Python library. 

Front-end:
The front-end for the search engine was hosted in an S3 bucket due to its static web hosting capability. Here, there was a search bar that the user entered their search term. After clicking search a JS function was called that passed the search term to the back-end using an API and the result was returned, parsed and displayed to the user. Error detection was also implemented on the front-end. 

Search:
The search mechanism was used to actually implement the search functionality of the back-end. To implement this, I used an AWS Service called AWS CloudSearch which created a searchable index of my back-end datastore, making the scraped documeents searchable. Two instances of CloudSearch were used, one for the main search result data from the main data store, and the other for searching and indexing the ads data store. CloudSearch sat between the front-end API and the data stores; CloudSearch received the search term from the front-end API and then searched for the term in the indexed documents pulled from the DynamoDB tables. 

Back-end:
The back-end was made up of all the components not visible to the user which included the API gateway's, search mechanism and data stores. The API gateways allowed for the search term to be passed from front-end to the CloudSearch instances, which would then search through the indexed data pulled from the data stores to return to user. The two data stores were implemented using DynamoDB, a key-value document NoSQL data storage structure.

Logging:
Monitoring and logging was also implemented in the QSE. A plethora of metrics and dimensions from each of the system's components were monitored with various alarms and events triggered if the monitiored metrics surpassed a threshold or if an error in the components occurred. Data from the components was also collected and logged within an S3 bucket. The CloudWatch service was used for this monitoring and logging. 

Deployment Scipts:
I created Terraform scripts for the 3 main cloud providers; AWS, GCP, Azure. These scripts, when executed, automatically spun up the required resources and instances of the components required for the system. This was an implementation of infastructure-as-a-code. 

Ci/CD pipelining:
I implemented continuous integration/continuous deployment using the AWS CodePipeline service. This service ensured that any changes made to the code of the front-end or the web scraper, passed the relevant steps before live deployment. The first stage of my pipeline was AWS CodeCommit, which I used as a repository for my code. The next stage was CodeBuild, where my source code was compiled and tests were ran. The final stage of the pipeline executed if the previous stages passed and it involved the deployment to the S3 bucket were the front-end was hosted. 

The design of this system on AWS can be seen below:
![alt text](https://github.com/amckenna41/search_engine/blob/master/AWSSystemDesign.png?raw=true)
