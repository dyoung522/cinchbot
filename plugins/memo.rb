#!/usr/bin/env ruby

require 'cinch'
require 'nosequel'

class Memo
  include Cinch::Plugin
  include Cinch::Extensions::Authentication

  def initialize(*args)
    super
    @storage = NoSequel.register(:memos, bot.config.storage)
  end

  set :plugin_name, 'memo'
  set :help, <<-USAGE.gsub(/^\s*/, '')
  !#{self.plugin_name} add <nick> <message> : Stores <message> for <nick>, which will be displayed the next time they are active.
  !#{self.plugin_name} del <nick>           : Deletes any memos for <nick>        [Admin Only]
  !#{self.plugin_name} list                 : Shows a list of all memos available [Admin Only]
  USAGE

  match /memo list/, :method => :list_store
  match /memo add (\S+) (.+)/, :method => :store
  match /memo (?:rem(?:ove)?|del(?:ete)?) (\S+)/, :method => :list_delete

  listen_to :message
  def listen(m)
    if @storage.exists?(m.user.nick)
      seq = 0
      @storage[m.user.nick].each do |message|
        m.user.send "[%02d] %s" % [ seq += 1, message ]
      end
      @storage.delete(m.user.nick)
    end
  end

  def list_store(m)
    return unless authenticated?( m, [ :owners, :admins ] )
    if @storage.count > 0
      m.user.send "Here are the memos I've got stored..."
      @storage.keys.each do |nick|
        seq = 0
        m.user.send "Messages for #{nick}:"
        @storage[nick].each do |message|
          m.user.send "[%02d] \"%s\"" % [ seq += 1, message ]
        end
      end
    else
      m.user.send "There are no memos stored."
    end
  end

  def list_delete(m, nick)
    return unless authenticated?( m, [ :owners, :admins ] )
    if @storage.exists?(nick)
      @storage.delete(nick)
      m.user.send "Message(s) for #{nick} have been removed"
    else
      m.user.send "No message(s) were found for #{nick}"
    end
  end

  def store(m, nick, message)
    return unless authenticated?(m)

    if nick == m.user.nick
      m.reply "You can't leave memos for yourself.."
    elsif nick == bot.nick
      m.reply "You can't leave memos for me.."
    else
      @storage[nick] = ( @storage.exists?(nick) ? @storage[nick] : Array.new ) << '[%s] <%s/%s> %s' % [
          Time.now.asctime,
          ( m.channel.nil? ? '[PM]' : m.channel.name ),
          m.user.name,
          message
      ]
      m.reply "Added memo for #{nick}"
    end
  end
end

