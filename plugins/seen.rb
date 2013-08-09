require 'cinch'

class Seen
  include Cinch::Plugin

  # Create the new Struct class, then monkey-patch it.  This is necessary so we don't end up
  # with a superclass mismatch if it's reloaded.
  SeenStruct = Struct.new(:who, :where, :what, :time)
  class SeenStruct
    def to_s
      "[#{time.asctime}] #{who} was seen in #{where} saying #{what}"
    end
  end

  set :plugin_name, 'seen'
  set :help, "Usage: !#{self.plugin_name} <nick> : Displays last seen information for <nick>"

  listen_to :channel
  match /seen (\S+)/

  def initialize(*args)
    super
    @users = {}
  end

  def listen(m)
    @users[m.user.nick.downcase] = SeenStruct.new(m.user, m.channel, m.message, Time.now)
  end

  def execute(m, nick)
    if nick.downcase == @bot.nick.downcase
      m.reply "That's me!"

    elsif nick.downcase == m.user.nick.downcase
      m.reply "That's you!"

    elsif @users.key?(nick.downcase)
      m.reply @users[nick.downcase].to_s

    else
      m.reply "I haven't seen #{nick}"

    end
  end
end
