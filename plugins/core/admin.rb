class Admin
    include Cinch::Plugin
    include Cinch::Extensions::Authentication

    match /quit\s*(.*)/                     , :method => :bot_quit
    match /(?:leave|part)\s*(\S*)\s*(.*)/   , :method => :bot_part
    match /join\s*(\S+)/                    , :method => :bot_join

    def bot_quit( m, msg = nil )
        return unless authenticated?( m, :owner )
        m.bot.quit msg.to_s
    end

    def bot_part( m, channel = nil, reason = nil )
        return unless authenticated?( m, :admins )

        channel = m.channel if channel.to_s.empty?

        if bot.channels.include?(channel)
            bot.part( channel, reason || "requested by #{m.nick}" )
        else
            m.reply "I'm not in #{channel}"
        end
    end

    def bot_join( m, channel )
        return unless authenticated?( m, :admins )

        if channel
            bot.join channel
        else
            m.reply 'Usage: join <channel>'
        end
    end
end
