news-crawler
============

### A news site crawler for extracting article information

This is mostly an attempt to get the hang of Ruby and how it fits in the 
context of the data journalistic approach i am trying to take.

The function the script is supposed to perform is that of parsing the RSS
feeds of 3 major newsrooms in Greece, fetch the articles and extract information
such as title, publication date and most importantly, provided source. The result
gets stored in a sqlite3 database which has a very simple schema - see source for
details.

To run this, you need a Ruby runtime environment and bundler installed. After cloning,
execute

> bundle install

followed by

> ruby crawler.rb

This will go off and fetch all the latest news from the 3 sites, storing them in a 
database in the same directory - a file news.db will be created to hold it. 

That's about it for now, if there is interest in this work, i'll share more information.
