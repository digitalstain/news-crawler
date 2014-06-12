require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'data_mapper'
require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'dm-timestamps'
require 'ostruct'


DataMapper::setup(:default, File.join('sqlite3://', Dir.pwd, 'news.db'))

class Article
  include DataMapper::Resource

  property :id,        Serial
  property :guid,      String, :length => 300
  property :link,      String, :length => 300
  property :title,     Text
  property :pubDate,   DateTime
  property :publisher, String
  property :source,    String, :length => 100
  property :category,  String, :length => 40

end

DataMapper::Model.raise_on_save_failure = true
DataMapper.finalize()
DataMapper.auto_upgrade!

# 		<div class="description">
# text
# <br />
# text
# <br />
# text
# <br />
# text
# <br />
# text
# <br />
# Πηγή: ΑΠΕ
# 		</div>

	# articlePage = Nokogiri::HTML(open("http://www.zougla.gr/money/article/eksagoges-me-pliromi-se-rouvlia-eksetazi-i-mosxa"))

		
# Since we'll iterate in order, stick the colon there to trim it if present after the word prefix is gone


def stripPrefix( stringToStrip )
	sourcePrefix = ["Πηγή", "Πηγές", "πηγή", "πηγές", ":" ]
		sourcePrefix.each { |prefix|
		if stringToStrip.start_with?(prefix)
			stringToStrip = stringToStrip[prefix.length..-1].strip
		end
	}
	return stringToStrip
end


class ZouglaRssParser
	def parseRss( rss )
		# Does not work, returns no results
		rss.xpath("//feed").each { |item|
			
			article = Article.new
			puts "id ->" + item.xpath("id").text
			puts "link ->" + item.xpath("link[@href]/@href").text
			puts "title -> " + item.xpath("title").text
			puts "date ->" + item.xpath("published").text
			yield article
		}
	end
end

class ParserForZougla
	def initialize
		@rssLocation = "http://www.zougla.gr/articlerss.xml"
	end

	def getRss
		return Nokogiri::XML(open(@rssLocation))
	end

	def fill ( article )
			articlePage = Nokogiri::HTML(open(article.link))
			# Zougla does not put references in tags, it's part of the article text.
			# It may or many not have a source, have to do a bit of guesswork. It's probably the last line of text
			candidateSource = articlePage.css("div.description").text.lines[-1]
			candidateSource = candidateSource.length > 50 ? "" : stripPrefix( candidateSource )
			article.source = candidateSource
			article.publisher = "Enet"
	end
end

class ParserForEnet

	def initialize
		@rssLocationPolitics = "http://www.enet.gr/rss?i=news.el.categories&c=politikh"
		@rssLocationGreece = "http://www.enet.gr/rss?i=news.el.categories&c=ellada"
		@rssLocationEconomy = "http://www.enet.gr/rss?i=news.el.categories&c=oikonomia"
	end

	def getRssPolitics
		return Nokogiri::XML(open(@rssLocationPolitics))
	end

	def getRssGreece
		return Nokogiri::XML(open(@rssLocationGreece))
	end

	def getRssEconomy
		return Nokogiri::XML(open(@rssLocationEconomy))
	end

	def fill ( article )
			articlePage = Nokogiri::HTML(open(article.link))
			# Enet is a PITA. It may or many not have a source, have to do a bit of guesswork
			candidateSource = articlePage.css("div#post-content > p").last.text.strip!
			article.source = candidateSource.length > 50 ? "" : stripPrefix( candidateSource )
			article.publisher = "Enet"
	end
end

class ParserForKathimerini

	def initialize
		@rssLocationGreece = "http://www.kathimerini.gr/rss?i=news.el.politikh"
		@rssLocationEconomy = "http://www.kathimerini.gr/rss?i=news.el.ellhnikh-oikonomia"
	end

	def getRssEconomy
		return Nokogiri::XML(open(@rssLocationEconomy))
	end

	def getRssGreece
		return Nokogiri::XML(open(@rssLocationGreece))
	end

	def fill ( article )		
			articlePage = Nokogiri::HTML(open(article.link))
			article.source = articlePage.css("article#item-article > header > span.item-source").text.strip
			article.publisher = "kathimerini"
	end
end

class ParserForInGr

	def initialize
		@rssLocationEconomy = "http://rss.in.gr/feed/news/economy/"
		@rssLocationGreece = "http://rss.in.gr/feed/news/greece/"
	end

	def getRssEconomy
		return Nokogiri::XML(open(@rssLocationEconomy))
	end

	def getRssGreece
		return Nokogiri::XML(open(@rssLocationGreece))
	end

	def fill ( article )
		articlePage = Nokogiri::HTML(open(article.link))
		article.source = articlePage.css("p.credits").text.strip
		article.publisher = "in.gr"
	end
end

class RssParser
	def parseRss( rss )
		rss.xpath("//item").each { |item|
			article = Article.new
			article.guid = item.xpath("guid").text
			article.link = item.xpath("link").text
			article.title = item.xpath("title").text
			article.pubDate = item.xpath("pubDate").text
			yield article
		}
	end
end

def doTheThing()

	rssParser = RssParser.new
	ingrParser = ParserForInGr.new
	kathimeriniParser = ParserForKathimerini.new
	enetParser = ParserForEnet.new

	begin		
		inRssEconomy = ingrParser.getRssEconomy
		inRssGreece = ingrParser.getRssGreece
	rescue
		puts "Failed to open rss for in.gr"
	else
		rssParser.parseRss( inRssGreece ) { |article| 
			if ( Article.first( :guid => article.guid) == nil )
				puts "#{article.link} was not there, filling"
				begin
					ingrParser.fill ( article )
					article.category = "greece"
				rescue
					puts "Failed to open article #{article.link}"
				else
					article.save
				end
			elsif 
				puts "#{article.link} was already there, skipping"
			end
		}
		rssParser.parseRss( inRssEconomy ) { |article| 
			if ( Article.first( :guid => article.guid) == nil )
				puts "#{article.link} was not there, filling"
				begin
					ingrParser.fill ( article )
					article.category = "economy"
				rescue
					puts "Failed to open article #{article.link}"
				else
					article.save
				end
			elsif 
				puts "#{article.link} was already there, skipping"
			end
		}

	end

	begin		
		kathimeriniRssEconomy = kathimeriniParser.getRssEconomy
		kathimeriniRssGreece = kathimeriniParser.getRssGreece
	rescue
		puts "Failed to open rss for kathimerini"
	else
		rssParser.parseRss( kathimeriniRssEconomy ) { |article| 
			if ( Article.first( :guid => article.guid) == nil )
				puts "#{article.link} was not there, filling"
					begin
						kathimeriniParser.fill ( article )
						article.category = "economy"
					rescue
						puts "Failed to open article #{article.link}"
					else
						article.save
					end
			elsif 
				puts "#{article.link} was already there, skipping"
			end
		}
		rssParser.parseRss( kathimeriniRssGreece ) { |article| 
			if ( Article.first( :guid => article.guid) == nil )
				puts "#{article.link} was not there, filling"
					begin
						kathimeriniParser.fill ( article )
						article.category = "greece"
					rescue
						puts "Failed to open article #{article.link}"
					else
						article.save
					end
			elsif 
				puts "#{article.link} was already there, skipping"
			end
		}
	end

	begin		
		enetRssEconomy = enetParser.getRssEconomy
		enetRssGreece = enetParser.getRssGreece
		enetRssPolitics = enetParser.getRssPolitics
	rescue
		puts "Failed to open rss for kathimerini"
	else
		rssParser.parseRss( enetRssEconomy ) { |article| 
			if ( Article.first( :guid => article.guid) == nil )
				puts "#{article.link} was not there, filling"
					begin
						enetParser.fill ( article )
						article.category = "economy"
					rescue
						puts "Failed to open article #{article.link}"
					else
						article.save
					end
			elsif 
				puts "#{article.link} was already there, skipping"
			end
		}
		rssParser.parseRss( enetRssGreece ) { |article| 
			if ( Article.first( :guid => article.guid) == nil )
				puts "#{article.link} was not there, filling"
					begin
						enetParser.fill ( article )
						article.category = "greece"
					rescue
						puts "Failed to open article #{article.link}"
					else
						article.save
					end
			elsif 
				puts "#{article.link} was already there, skipping"
			end
		}
			rssParser.parseRss( enetRssPolitics ) { |article| 
			if ( Article.first( :guid => article.guid) == nil )
				puts "#{article.link} was not there, filling"
					begin
						enetParser.fill ( article )
						article.category = "greece"
					rescue
						puts "Failed to open article #{article.link}"
					else
						article.save
					end
			elsif 
				puts "#{article.link} was already there, skipping"
			end
		}
	end

end

doTheThing
