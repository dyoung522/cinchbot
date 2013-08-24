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
  !#{self.plugin_name} <nick> <message> :  Stores <message> for <nick>, which will be displayed the next time they are active.
  !#{self.plugin_name} list : Shows a list of all memos available [Admin Only]
  !#{self.plugin_name} del <nick> : Deletes any memos for <nick>  [Admin Only]
  USAGE

  match /memo (.+?) (.+)/, :method => :store
  match /memo list/, :method => :list_store
  match /memo del/, :method => :list_delete

  listen_to :message
  def listen(m)
    if @storage.exists?(m.user.nick)
      m.user.send @storage.delete(m.user.nick)
    end
  end

  def list_store(m)
    return unless authenticated?( m, [ :owners, :admins ] )
    m.user.send "Here are the memos I've got stored..."
    @storage.each do |nick, message|
      m.user.send "For: #{nick} / \"#{message}\""
    end
  end

  def list_delete(m, nick)
    return unless authenticated?( m, [ :owners, :admins ] )
    if @storage.exists?(nick)
      @storage.delete(nick)
      m.user.send "Message for #{nick} has been removed"
    else
      m.user.send "No message were found for #{nick}"
    end
  end

  def store(m, nick, message)
    if @storage.exists?(nick)
      m.reply "There's already a memo for #{nick}. You can only store one right now"
    elsif nick == m.user.nick
      m.reply "You can't leave memos for yourself.."
    elsif nick == bot.nick
      m.reply "You can't leave memos for me.."
    else
      @storage[nick] = "[#{Time.now.asctime}] <#{m.channel.name}/#{m.user.name}> #{message}"
      m.reply "Added memo for #{nick}"
    end
  end
end

