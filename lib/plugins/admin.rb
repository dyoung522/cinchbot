class Admin
  include Cinch::Plugin
  include Cinch::Extensions::Authentication

  set :plugin_name, 'admin'
  set :help, <<-USAGE.gsub(/^\s*/, '')
      Includes several admin-level bot commands:
      - !join <channel>                   : join <channel>
      - !part [channel] [reason]          : leave [channel] with [reason] (current if channel omitted)
      - !quit [reason]                    : quit with reason (terminates bot)

      - !nick <nick>                      : Change the bot's nick to <nick>

      - !user add_to <level> <nickname>   : Adds a user to the <level> list.
      - !user del_from <level> <nickname> : Deletes a user from the <level> list.
      - !user list <level>                : Shows the <level> list.

      - !version                          : Display bot version information
  USAGE

  match /version/, :method => :show_ver
  def show_ver(m)
    return unless authenticated?( m, [ :owners, :admins, :users ] )
    m.reply sprintf "%s - v%s by %s\n", $PROGRAM, $VERSION, $AUTHOR
  end

  # Quit, Part, Join
  match /quit\s*(.*)/                                 , :method => :bot_quit
  match /(?:leave|part)(?:\s+(#\S+))?(?:\s+(.*))?/    , :method => :bot_part
  match /join\s+(#\S+)/                               , :method => :bot_join
  match /nick\s+(\S+)/                                , :method => :bot_nick

  def bot_quit( m, msg = nil )
    return unless authenticated?( m, :owners )
    m.bot.quit msg.to_s
  end

  def bot_part( m, channel = nil, reason = nil )
    return unless authenticated?( m, [ :owners, :admins ] )

    channel ||= m.channel
    reason  ||= "requested by #{m.user}"

    if bot.channels.include?(channel)
      bot.part( channel, reason )
    else
      m.reply "Sorry, but I'm not in #{channel}"
    end
  end

  def bot_join( m, channel )
    return unless authenticated?( m, [ :owners, :admins ] )
    Channel(channel).join
  end

  def bot_nick( m, nick )
    return unless authenticated?( m, [ :owners ] )
    bot.nick=nick
  end


  # User Management
  match /user add(?:_to)? (\S+) (\S+)/s,           :method => :user_add
  match /user del(?:ete)?(?:_from)? (\S+) (\S+)/s, :method => :user_del
  match /user list (\S+)/s,                        :method => :user_list

  def user_add(m, level, nickname)
    return unless authenticated?( m, [ :owners, :admins ] )
    if bot.config.authentication.send(level) << nickname
      m.user.notice "#{nickname} has been added to the #{level} list."
    end
  end

  def user_del(m, level, nickname)
    return unless authenticated?( m, [ :owners, :admins ] )
    if bot.config.authentication.send(level).delete nickname
      m.user.notice "#{nickname} has been deleted from the #{level} list."
    end
  end

  def user_list(m, level)
    return unless authenticated?( m, [ :owners, :admins ] )
    if bot.config.authentication.respond_to?(level)
      m.user.notice "Users in #{level}: #{bot.config.authentication.send(level).join( ', ' )}"
    else
      m.user.notice "#{level} is not a valid level"
    end
  end
end