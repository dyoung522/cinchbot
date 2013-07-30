require 'cinch'
require 'open-uri'
require 'nokogiri'
require 'cgi'

class Google
  include Cinch::Plugin

  set :plugin_name, 'google'
  set :help, "Usage: !#{self.plugin_name} <lookup> : Performs a Google search on <lookup>"

  match /google (.+)/

  def search(query)
    url = "http://www.google.com/search?q=#{CGI.escape(query)}"
    res = Nokogiri::HTML(open(url)).at("h3.r")

    title = res.text
    link = res.at('a')[:href]
    desc = res.at("./following::div").children.first.text
    CGI.unescape_html "#{title} - #{desc} (#{link})"
  rescue
    "No results found"
  end

  def execute(m, query)
    m.reply(search(query))
  end
end
