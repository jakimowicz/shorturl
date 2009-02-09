# shorturl.rb
#
#   Created by Vincent Foley on 2005-06-02
#

require "net/http"
require "cgi"
require "uri"

class InvalidService < Exception
end

class Service
  attr_accessor :port, :code, :method, :action, :field, :block

  # Intialize the service with a hostname (required parameter) and you
  # can override the default values for the HTTP port, expected HTTP
  # return code, the form method to use, the form action, the form
  # field which contains the long URL, and the block of what to do
  # with the HTML code you get.
  def initialize(hostname) # :yield: service
    @hostname = hostname
    @port = 80
    @code = 200
    @method = :post
    @action = "/"
    @field = "url"
    @cache = {}
    @block = lambda { |body| }

    if block_given?
      yield self
    end
  end

  # Now that our service is set up, call it with all the parameters to
  # (hopefully) return only the shortened URL.
  def call(url)
    @cache[url] ||= Net::HTTP.start(@hostname, @port) { |http|
      response = case @method
                 when :post: http.post(@action, "#{@field}=#{url}")
                 when :get: http.get("#{@action}?#{@field}=#{CGI.escape(url)}")
                 end
      handle response
    }
  end
  
  # Parse response using @block.
  # This functions was written to be redefined in some services
  def handle(response)
    if response.code == @code.to_s
      @block.call(response.read_body)
    end
  end
end

class ShortURL
  # Hash table of all the supported services.  The key is a symbol
  # representing the service (usually the hostname minus the .com,
  # .net, etc.)  The value is an instance of Service with all the
  # parameters set so that when +instance+.call is invoked, the
  # shortened URL is returned.
  @@services = {
    :rubyurl => Service.new("rubyurl.com") { |s|
      s.action = "/rubyurl/remote"
      s.field = "website_url"
      s.block = lambda { |body| URI.extract(body).grep(/rubyurl/)[0] }      
    },
    
    :tinyurl => Service.new("tinyurl.com") { |s|
      s.action = "/api-create.php"
      s.block = lambda { |body| URI.extract(body).grep(/tinyurl/)[0] }
    },
    
    :shorl => Service.new("shorl.com") { |s|
      s.action = "/create.php"
      s.block = lambda { |body| URI.extract(body)[2] }
    },

    :metamark => Service.new("metamark.net") { |s|
      s.action = "/add"
      s.field = "long_url"
      s.block = lambda { |body| URI.extract(body).grep(/xrl.us/)[0] }
    },

    :shorterlink => Service.new("shorterlink.com") { |s|
      s.method = :get
      s.action = "/add_url.html"
      s.block = lambda { |body| URI.extract(body).grep(/shorterlink/)[0] }
    },
    
    :minilink => Service.new("minilink.org") { |s|
      s.method = :get
      s.block = lambda { |body| URI.extract(body)[-1] }
    },

    :lns => Service.new("ln-s.net") { |s|
      s.method = :get
      s.action = "/home/api.jsp"
      s.block = lambda { |body| URI.extract(body)[0] }
    },

    :fyad => Service.new("fyad.org") { |s|
      s.method = :get
      s.block = lambda { |body| URI.extract(body).grep(/fyad.org/)[2] }
    },

    :d62 => Service.new("d62.net") { |s|
      s.method = :get
      s.block = lambda { |body| URI.extract(body)[0] }
    },

    :shiturl => Service.new("shiturl.com") { |s|
      s.method = :get
      s.action = "/make.php"
      s.block = lambda { |body| URI.extract(body).grep(/shiturl/)[0] }
    },

    :shortify => Service.new("shortify.wikinote.com") { |s|
      s.method = :get
      s.action = "/sshorten.php"
      s.field = "url"
      s.block = lambda { |body| URI.extract(body)[0] }
    },

    :moourl => Service.new("moourl.com") { |s|      
      s.code = 302
      s.action = "/create/"
      s.method = :get      
      s.field = "source"
      
      # Redefine handle function to get redirection code (moourl use http header redirection)
      def s.handle(response)
        response['Location'].gsub('/woot/?moo=','http://moourl.com/')
      end
    },
    
    :isgd => Service.new("is.gd") {|s|
      s.method = :get
      s.action = "/api.php"
      s.field = "longurl"
      s.block = lambda {|body| URI.extract(body)[0]}
    }
  }

  # Array containing symbols representing all the implemented URL
  # shortening services
  @@valid_services = @@services.keys

  # Returns @@valid_services
  def self.valid_services
    @@valid_services
  end

  # Main method of ShortURL, its usage is quite simple, just give an
  # url to shorten and an optional service.  If no service is
  # selected, RubyURL.com will be used.  An invalid service symbol
  # will raise an ArgumentError exception
  #
  # Valid +service+ values:
  #
  # * <tt>:rubyurl</tt>
  # * <tt>:tinyurl</tt>
  # * <tt>:shorl</tt>
  # * <tt>:metamark</tt>
  # * <tt>:shorterlink</tt>
  # * <tt>:lns</tt>
  # * <tt>:fyad</tt>
  # * <tt>:d62</tt>
  # * <tt>:shiturl</tt>
  # * <tt>:shortify</tt>
  # * <tt>:isgd</tt>
  #
  # call-seq:
  #   ShortURL.shorten("http://mypage.com") => Uses RubyURL
  #   ShortURL.shorten("http://mypage.com", :tinyurl)
  def self.shorten(url, service = :rubyurl)
    service_or_raise(service).call(url)
  end

  # Search for given service and return it or raise InvalidService
  def self.service_or_raise(service)
    @@services[service] || raise InvalidService
  end
end