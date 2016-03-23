require 'rubygems'
require 'bundler/setup'

require 'typhoeus'
require 'nokogiri'
require 'open-uri'
require 'securerandom'

# The `Scraper` class scrapes finanzen.net to get a list of all stocks.
# To do so it extracts all indexes from the search form to make a search
# request to get all stocks per stock. In case of a paginated response it
# follows all subsequent linked pages.
# For each list a list gets created containing all stock links found on
# that page with the URL of the page in the first line.
#
# @example Start the scraping process.
#   Scraper.new.run
#
# @example Get a list of all stock indexes.
#   Scraper.new.indexes
#
# @example Get a list of all stocks of the DAX index.
#   Scraper.new.stocks('aktien/aktien_suche.asp?inIndex=1')
#   #=> [http://www.finanzen.net/aktien/adidas-Aktie,
#        http://www.finanzen.net/aktien/Allianz-Aktie, ...]
#
# @example Linked pages of the NASDAQ 100.
#   Scraper.new.linked_pages('aktien/aktien_suche.asp?inIndex=9')
#   #=> ['aktien/aktien_suche.asp?intpagenr=2&inIndex=9',
#        'aktien/aktien_suche.asp?intpagenr=3&inIndex=9']
class Scraper
  # Intialize the scraper.
  #
  # @example With the default file box location.
  #   Scraper.new
  #
  # @example With a custom file box location.
  #   Scraper.new file_box: '/Users/katzer/tmp'
  #
  # @param [ String ] file_box: Optional information where to place the result.
  #
  # @return [ Scraper ] A new scraper instance.
  def initialize(file_box: 'vendor/mount')
    @file_box = File.join(file_box, SecureRandom.uuid)
    @hydra    = Typhoeus::Hydra.new
  end

  attr_reader :file_box

  # Scrape all indexes from the page found under the `inIndex` menu.
  #
  # @example Scrape the indexes found at finanzen.net.
  #   indexes
  #   #=> [1, 2, 3, ...]
  #
  # @return [ Array<Int> ] All found stock indexes.
  def indexes
    sel  = '#frmAktienSuche table select[name="inIndex"] option:not(:first-child)' # rubocop:disable Metrics/LineLength
    page = Nokogiri::HTML(open(abs_url('aktien/aktien_suche.asp')))

    page.css(sel).map { |opt| opt.values[0].strip }
  rescue Timeout::Error
    []
  end

  # Scrape all stocks found on the specified search result page.
  #
  # @example Scrape stocks of the DAX index
  #   stocks('aktien/aktien_suche.asp?inIndex=1')
  #   #=> [http://www.finanzen.net/aktien/adidas-Aktie,
  #        http://www.finanzen.net/aktien/Allianz-Aktie, ...]
  #
  # @param [ Nokogiri::HTML ] page A parsed search result page.
  #
  # @return [ Array<URI> ] List of URIs pointing to each stocks page.
  def stocks(page)
    sel = '#mainWrapper > div.main > div.table_quotes > div.content > table tr > td:not(.no_border):first-child > a:first-child' # rubocop:disable Metrics/LineLength

    page.css(sel).map { |link| abs_url link.attributes['href'].value }
  end

  # Determine whether the scraper has to follow linked lists in case of
  # pagination. To follow is only required if the URL of the response
  # does not include the `intpagenr` query attribute.
  #
  # @example Follow paginating of the 1st result page of the NASDAQ.
  #   follow_linked_pages? 'aktien/aktien_suche.asp?inIndex=9'
  #   #=> true
  #
  # @example Follow paginating of the 2nd result page of the NASDAQ.
  #   follow_linked_pages? 'aktien/aktien_suche.asp?inIndex=9&intpagenr=2'
  #   #=> false
  #
  # @param [ String|URI ] url The URL of the HTTP request.
  #
  # @return [ Boolean ] true if the linked pages have to be scraped as well.
  def follow_linked_pages?(url)
    url.to_s.length <= 80 # URL with intpagenr has length > 80
  end

  # Scrape all linked lists found on the specified search result page.
  #
  # @example Linked pages of the NASDAQ 100.
  #   linked_pages('aktien/aktien_suche.asp?inIndex=9')
  #   #=> ['aktien/aktien_suche.asp?intpagenr=2&inIndex=9',
  #        'aktien/aktien_suche.asp?intpagenr=3&inIndex=9']
  #
  # @param [ Nokogiri::HTML ] page A parsed search result page.
  #
  # @return [ Array<URI> ] List of URIs pointing to each linked page.
  def linked_pages(page)
    sel = '#mainWrapper > div.main > div.table_quotes > div.content > table tr:last-child div.paging > a:not(.image_button_right)' # rubocop:disable Metrics/LineLength
    page.css(sel).map { |link| abs_url link.attributes['href'].value }
  end

  # Scrape indexes form search page, then scrape all stocks per index.
  def run
    url = 'aktien/aktien_suche.asp?inBranche=0&inLand=0'

    FileUtils.mkdir_p @file_box

    indexes.each { |index| scrape "#{url}&inIndex=#{index}" }

    @hydra.run
  end

  private

  # Scrape the listed stocks from the search result for a pre-given index.
  # The method workd async as the `on_complete` callback of the response
  # object delegates to the scrapers `on_complete` method.
  #
  # @param [ String ] url A relative URL of a page with search results.
  #
  # @return [ Void ]
  def scrape(url)
    req = Typhoeus::Request.new(abs_url(url))

    req.on_complete(&method(:on_complete))

    @hydra.queue req
  end

  # Callback of the `scrape` method once the request is complete.
  # The containing stocks will be saved to into a file. If the list is
  # paginated then the linked pages will be added to the queue.
  #
  # @param [ Typhoeus::Response ] res The response of the HTTP request.
  #
  # @return [ Void ]
  def on_complete(res)
    url    = res.request.url
    page   = Nokogiri::HTML(res.body)
    stocks = stocks(page).unshift(url)

    upload_stocks(stocks)
    linked_pages(page).each { |site| scrape site } if follow_linked_pages? url
  end

  # Save the list of stock links in a file. The location of that file is the
  # former provided @file_box path or its default value.
  #
  # @example To save a file.
  #   upload_stocks(['http://www.finanzen.net/aktien/adidas-Aktie'])
  #   #=> <File:/tmp/0c265f57-999f-497e-9dd0-eb8ee55a8b0e.txt>
  #
  # @param [ Array<String> ] stocks List of stock links.
  #
  # @return [ File ] The created file.
  def upload_stocks(stocks)
    File.open(File.join(@file_box, "#{SecureRandom.uuid}.txt"), 'w+') do |file|
      stocks.each { |stock| file << "#{stock}\n" }
    end
  end

  # Add host and protocol to the URI to be absolute.
  #
  # @example
  #   abs_url('aktien/aktien_suche.asp')
  #   #=> 'http://www.finanzen.net/aktien/aktien_suche.asp'
  #
  # @param [ String ] A relative URI.
  #
  # @return [ String ] The absolute URI.
  def abs_url(url)
    URI.join('http://www.finanzen.net', URI.escape(url.to_s))
  end
end
