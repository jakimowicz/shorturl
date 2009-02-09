# tc_shortcut.rb
#
#   Created by Vincent Foley on 2005-06-01

$test_lib_dir = File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift($test_lib_dir)

require "test/unit"
require "net/http"
require "uri"
require "shorturl"

class TestShortURL < Test::Unit::TestCase
  def setup
    @url = "http://groups.google.com/group/comp.lang.ruby/"
  end
  
  def test_shorten
    # Default service (RubyURL)
    assert_equal @url, fetch_redirection(ShortURL.shorten(@url), @url)

    # All the services
    ShortURL.valid_services.each do |service|
      assert_equal @url, fetch_redirection(ShortURL.shorten(@url, service), @url)
    end
    
    # An invalid service
    assert_raise(InvalidService) { ShortURL.shorten(@url, :foobar) }
  end
  
  protected
  # Follow redirections and returns final url
  def fetch_redirection(orig, stop = nil)
    uri = URI.parse(orig)
    Net::HTTP.start(uri.host, uri.port) do |http|
      answer = http.get(uri.path)
      destination = answer['Location'] || answer.body.match(/http-equiv=\"refresh\".*content=\"[0-9]+; url=(.*)\"/i).captures.first.gsub(/(\'|\")/, '')
      destination == stop ? destination : fetch_redirection(destination, stop)
    end
  rescue => e
    nil
  end
end