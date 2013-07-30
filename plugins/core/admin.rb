class Admin
    include Cinch::Plugin
    include Cinch::Extensions::Authentication

    match /quit\s*(.*)/                                 , :method => :bot_quit
    match /(?:leave|part)(?:\s+(#\S+))?(?:\s+(.*))?/    , :method => :bot_part
    match /join\s+(#\S+)/                               , :method => :bot_join

    def bot_quit( m, msg = nil )
        return unless authenticated?( m, :owner )
        m.bot.quit msg.to_s
    end

    def bot_part( m, channel = nil, reason = nil )
        return unless authenticated?( m, :admins )

        channel ||= m.channel
        reason  ||= "requested by #{m.user}"

        if bot.channels.include?(channel)
            bot.part( channel, reason )
        else
            m.reply "Sorry, but I'm not in #{channel}"
        end
    end

    def bot_join( m, channel )
        return unless authenticated?( m, :admins )
        Channel(channel).join
    end

end
