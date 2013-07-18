class Admin
  include Cinch::Plugin
  include Cinch::Extensions::Authentication

  match /^quit (.*)/, :method => :bot_quit

  def bot_quit m, msg
    return unless authenticated? m
    m.bot.quit( msg )
  end
end
